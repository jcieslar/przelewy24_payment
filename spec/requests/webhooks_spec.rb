# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Przelewy24 webhooks", type: :request do
  let(:base) { "https://sandbox.przelewy24.pl/api/v1" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:order) { Order.create! }
  let!(:payment) { Przelewy24Payment::Payment.create!(payable: order, session_id: "SESS1", amount: 1000, currency: "PLN") }
  let(:payload) { Przelewy24Payment::TestHelpers.status_payload(payment) }
  let(:verified) { [] }

  before do
    calls = verified
    Przelewy24Payment.configuration.on_payment_verified = ->(p) { calls << p.id }
  end

  def verify_stub(status)
    stub_request(:put, "#{base}/transaction/verify").to_return(body: { data: { status: status } }.to_json, headers: json)
  end

  def deliver(params = payload) = post("/przelewy24/webhooks/status", params: params, as: :json)

  it "verifies the payment once and fires the callback" do
    stub = verify_stub("success")
    deliver
    expect(response).to have_http_status(:ok)
    expect(payment.reload).to have_attributes(status: "verified", p24_order_id: 123_456, method_id: 25)
    expect(payment.verified_at).to be_present

    deliver # duplicate delivery
    expect(response).to have_http_status(:ok)
    expect(stub).to have_been_requested.once
    expect(verified).to eq([ payment.id ])
  end

  it "retries a raising callback on the next delivery without re-verifying" do
    stub = verify_stub("success")
    attempts = 0
    Przelewy24Payment.configuration.on_payment_verified = ->(_) { (attempts += 1) == 1 ? raise("db down") : nil }

    deliver
    expect(response).to have_http_status(:internal_server_error)
    expect(payment.reload).to have_attributes(status: "verified", notified_at: nil)

    deliver
    expect(response).to have_http_status(:ok)
    expect(payment.reload.notified_at).to be_present
    expect(attempts).to eq(2)
    expect(stub).to have_been_requested.once
  end

  it "rolls back database changes made by a raising callback" do
    verify_stub("success")
    Przelewy24Payment.configuration.on_payment_verified = ->(p) { p.payable.touch(:updated_at); raise "boom" }
    expect { deliver }.not_to(change { order.reload.updated_at })
  end

  it "marks the payment failed when verification fails" do
    verify_stub("error")
    failed = []
    Przelewy24Payment.configuration.on_payment_failed = ->(p) { failed << p.id }
    deliver
    expect(payment.reload.status).to eq("failed")
    expect(failed).to eq([ payment.id ])
  end

  it "keeps the payment pending when Przelewy24 is down so it retries" do
    stub_request(:put, "#{base}/transaction/verify").to_return(status: 500, body: "{}", headers: json)
    deliver
    expect(response).to have_http_status(:internal_server_error)
    expect(payment.reload.status).to eq("pending")
  end

  it "rejects a bad signature" do
    deliver(payload.merge("sign" => "0" * 96))
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects incomplete payloads" do
    deliver(payload.except("orderId"))
    expect(response).to have_http_status(:bad_request)
  end

  it "returns 404 for an unknown session" do
    attrs = payload.merge("sessionId" => "NOPE").except("sign")
    deliver(attrs.merge("sign" => Przelewy24Payment::Signature.notification(attrs, crc: "crc-key")))
    expect(response).to have_http_status(:not_found)
  end

  it "enforces the IP allowlist" do
    Przelewy24Payment.configuration.allowed_ips = [ "1.2.3.4" ]
    deliver
    expect(response).to have_http_status(:forbidden)
  end

  it "accepts a webhook from an allowed CIDR range" do
    verify_stub("success")
    Przelewy24Payment.configuration.allowed_ips = [ "127.0.0.0/8" ]
    deliver
    expect(response).to have_http_status(:ok)
  end

  it "marks a rejected refund as failed" do
    refund = Przelewy24Payment::Refund.create!(payment: payment, amount: 500, request_id: "r", refunds_uuid: "U2")
    attrs = { "orderId" => 9, "sessionId" => "SESS1", "refundsUuid" => "U2", "merchantId" => 12_345,
              "amount" => 500, "currency" => "PLN", "status" => 1 }
    post "/przelewy24/webhooks/refund", params: attrs.merge("sign" => Przelewy24Payment::Signature.refund_notification(attrs, crc: "crc-key")), as: :json
    expect(refund.reload.status).to eq("failed")
  end

  it "handles refund notifications" do
    refund = Przelewy24Payment::Refund.create!(payment: payment, amount: 500, request_id: "r", refunds_uuid: "U1")
    attrs = { "orderId" => 9, "sessionId" => "SESS1", "refundsUuid" => "U1", "merchantId" => 12_345,
              "amount" => 500, "currency" => "PLN", "status" => 0 }
    post "/przelewy24/webhooks/refund", params: attrs.merge("sign" => Przelewy24Payment::Signature.refund_notification(attrs, crc: "crc-key")), as: :json
    expect(response).to have_http_status(:ok)
    expect(refund.reload.status).to eq("completed")
  end
end
