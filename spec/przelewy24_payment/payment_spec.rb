# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Payment do
  let(:base) { "https://sandbox.przelewy24.pl/api/v1" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:order) { Order.create! }
  let(:args) do
    { payable: order, amount: BigDecimal("19.99"), currency: "PLN", email: "a@b.pl", description: "Order", return_url: "https://shop.test/o/1" }
  end

  it "registers a transaction and exposes the gateway redirect url" do
    stub = stub_request(:post, "#{base}/transaction/register").with { |req|
      JSON.parse(req.body).values_at("amount", "urlStatus") == [ 1999, "https://shop.test/przelewy24/webhooks/status" ]
    }.to_return(body: { data: { token: "TOK" } }.to_json, headers: json)

    payment = described_class.start!(**args)
    expect(payment).to be_persisted
    expect(payment.session_id).to match(/\A[A-Z0-9]{16}\z/)
    expect(payment.redirect_url).to eq("https://sandbox.przelewy24.pl/trnRequest/TOK")
    expect(payment.amount_decimal).to eq(BigDecimal("19.99"))
    expect(stub).to have_been_requested
    expect(order.przelewy24_payments).to include(payment)
  end

  it "marks the payment failed and re-raises when registration fails" do
    stub_request(:post, "#{base}/transaction/register").to_return(status: 400, body: { error: "bad" }.to_json, headers: json)
    expect { described_class.start!(**args) }.to raise_error(Przelewy24Payment::ValidationError)
    expect(described_class.last.status).to eq("failed")
  end

  it "creates a new session per attempt" do
    stub_request(:post, "#{base}/transaction/register").to_return(body: { data: { token: "T" } }.to_json, headers: json)
    sessions = 2.times.map { described_class.start!(**args).session_id }
    expect(sessions.uniq.size).to eq(2)
  end

  it "requests refunds only for verified payments" do
    payment = described_class.create!(payable: order, session_id: "S", amount: 1000, currency: "PLN")
    expect { Przelewy24Payment::Refund.request!(payment: payment, amount: 5) }.to raise_error(Przelewy24Payment::Error, /not verified/)

    payment.update!(status: "verified", p24_order_id: 9)
    stub_request(:post, "#{base}/transaction/refund").to_return(body: { data: [ { orderId: 9 } ] }.to_json, headers: json)
    refund = Przelewy24Payment::Refund.request!(payment: payment, amount: 5)
    expect(refund).to have_attributes(amount: 500, status: "pending")
  end

  describe "retrying a payment" do
    before { stub_request(:post, "#{base}/transaction/register").to_return(body: { data: { token: "T" } }.to_json, headers: json) }

    it "allows a new attempt after a failed or abandoned one" do
      first = described_class.start!(**args)
      first.update!(status: "failed")
      second = described_class.start!(**args)
      expect(order.przelewy24_payments.count).to eq(2)
      expect(second.session_id).not_to eq(first.session_id)
      expect(order.latest_przelewy24_payment).to eq(second)
    end

    it "refuses to start a payment for an already paid payable" do
      described_class.start!(**args).update!(status: "verified")
      expect(order).to be_przelewy24_paid
      expect { described_class.start!(**args) }.to raise_error(Przelewy24Payment::AlreadyPaidError)
      expect(order.przelewy24_payments.count).to eq(1)
    end

    it "expires only stale pending attempts" do
      old = described_class.start!(**args).tap { |p| p.update_columns(created_at: 3.days.ago) }
      fresh = described_class.start!(**args)
      done = described_class.start!(**args).tap { |p| p.update_columns(created_at: 3.days.ago, status: "failed") }

      expect(described_class.expire_stale!(older_than: 1.day)).to eq(1)
      expect([ old, fresh, done ].map { |p| p.reload.status }).to eq(%w[expired pending failed])
    end

    it "still settles a late notification for an expired attempt" do
      payment = described_class.start!(**args)
      payment.update!(status: "expired")
      stub_request(:put, "#{base}/transaction/verify").to_return(body: { data: { status: "success" } }.to_json, headers: json)
      notification = Przelewy24Payment::Notification.new(Przelewy24Payment::TestHelpers.status_payload(payment))

      expect(payment.settle!(notification)).to eq(:verified)
      expect(payment.reload).to be_verified
    end
  end
end
