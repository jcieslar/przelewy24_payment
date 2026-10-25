# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Api::Transactions do
  let(:base) { "https://sandbox.przelewy24.pl/api/v1" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:client) { Przelewy24Payment.client }

  it "registers a transaction with a valid signature and returns the token" do
    stub = stub_request(:post, "#{base}/transaction/register").with { |req|
      body = JSON.parse(req.body)
      body["sign"] == Przelewy24Payment::Signature.register(session_id: "S1", merchant_id: 12_345, amount: 1000, currency: "PLN", crc: "crc-key") &&
        body.values_at("merchantId", "posId", "country", "language") == [ 12_345, 12_345, "PL", "pl" ]
    }.to_return(body: { data: { token: "TOK" } }.to_json, headers: json)

    token = client.transactions.register(session_id: "S1", amount: 1000, currency: "PLN", description: "d",
                                         email: "a@b.pl", url_return: "https://x/r", url_status: "https://x/s")
    expect(token).to eq("TOK")
    expect(stub).to have_been_requested
  end

  it "verifies a transaction" do
    stub_request(:put, "#{base}/transaction/verify").to_return(body: { data: { status: "success" } }.to_json, headers: json)
    expect(client.transactions.verify(session_id: "S1", order_id: 9, amount: 1000, currency: "PLN")).to be true
  end

  it "returns false when verification is not successful" do
    stub_request(:put, "#{base}/transaction/verify").to_return(body: { data: { status: "error" } }.to_json, headers: json)
    expect(client.transactions.verify(session_id: "S1", order_id: 9, amount: 1000, currency: "PLN")).to be false
  end

  it "finds a transaction by session id" do
    stub_request(:get, "#{base}/transaction/by/sessionId/S1").to_return(body: { data: { orderId: 9 } }.to_json, headers: json)
    expect(client.transactions.find_by_session_id("S1")).to eq("orderId" => 9)
  end

  it "lists payment methods and refunds" do
    stub_request(:get, "#{base}/payment/methods/pl").to_return(body: { data: [ { id: 1 } ] }.to_json, headers: json)
    expect(client.payment_methods.list).to eq([ { "id" => 1 } ])

    stub_request(:post, "#{base}/transaction/refund").to_return(body: { data: [ { orderId: 9 } ] }.to_json, headers: json)
    result = client.refunds.create(request_id: "r", order_id: 9, session_id: "S1", amount: 100, url_status: "https://x")
    expect(result["refundsUuid"]).to match(/\A\h{8}-/)

    stub_request(:get, "#{base}/refund/by/orderId/9").to_return(body: { data: { refunds: [] } }.to_json, headers: json)
    expect(client.refunds.find(9)).to eq("refunds" => [])
  end
end
