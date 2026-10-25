# frozen_string_literal: true

require "spec_helper"

RSpec.describe "BLIK and card API" do
  let(:base) { "https://sandbox.przelewy24.pl/api/v1" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:client) { Przelewy24Payment.client }

  def reply(data, status: 200) = { status: status, body: data.to_json, headers: json }

  it "charges BLIK by code, sending alias and recurring only when given" do
    stub = stub_request(:post, "#{base}/paymentMethod/blik/chargeByCode").with(
      body: { token: "T", blikCode: "777123", aliasValue: "a-1", aliasLabel: "Label", recurring: { type: "M" } }.to_json
    ).to_return(reply({ data: { orderId: 55 } }, status: 201))

    order_id = client.blik.charge_by_code(token: "T", blik_code: "777123", alias_value: "a-1",
                                          alias_label: "Label", recurring: { type: "M" })
    expect(order_id).to eq(55)
    expect(stub).to have_been_requested

    plain = stub_request(:post, "#{base}/paymentMethod/blik/chargeByCode").with(body: { token: "T", blikCode: "1" }.to_json)
                                                                          .to_return(reply({ data: { orderId: 1 } }))
    client.blik.charge_by_code(token: "T", blik_code: "1")
    expect(plain).to have_been_requested
  end

  it "charges BLIK by alias and by alternative key" do
    stub_request(:post, "#{base}/paymentMethod/blik/chargeByAlias").with(body: { type: "alias", token: "T", aliasValue: "a" }.to_json)
                                                                    .to_return(reply({ data: { orderId: 7 } }))
    expect(client.blik.charge_by_alias(token: "T", alias_value: "a")).to eq(7)

    stub_request(:post, "#{base}/paymentMethod/blik/chargeByAlias").with(body: { type: "alternativeKey", token: "T", alternativeKey: "k" }.to_json)
                                                                    .to_return(reply({ data: { orderId: 8 } }))
    expect(client.blik.charge_by_alternative_key(token: "T", alternative_key: "k")).to eq(8)
  end

  it "raises AmbiguousAliasError with the alternative keys on HTTP 409" do
    stub_request(:post, "#{base}/paymentMethod/blik/chargeByAlias")
      .to_return(reply({ error: { message: "ambiguous", alternativeKeys: [ { key: "k1", label: "Bank A" } ] }, code: 51 }, status: 409))

    expect { client.blik.charge_by_alias(token: "T", alias_value: "a") }.to raise_error(Przelewy24Payment::AmbiguousAliasError, /ambiguous/) do |e|
      expect(e.alternative_keys).to eq([ { "key" => "k1", "label" => "Bank A" } ])
    end
  end

  it "lists aliases by email" do
    stub_request(:get, "#{base}/paymentMethod/blik/getAliasesByEmail/a%40b.pl").to_return(reply({ data: [ { value: "x" } ] }))
    stub_request(:get, "#{base}/paymentMethod/blik/getAliasesByEmail/a%40b.pl/custom").to_return(reply({ data: [ { value: "y" } ] }))
    expect(client.blik.aliases("a@b.pl")).to eq([ { "value" => "x" } ])
    expect(client.blik.aliases("a@b.pl", custom: true)).to eq([ { "value" => "y" } ])
  end

  it "reads a card reference and charges cards" do
    stub_request(:get, "#{base}/card/info/9").to_return(reply({ data: { refId: "REF" } }))
    expect(client.cards.reference_for(9)).to eq("REF")

    stub_request(:post, "#{base}/card/charge").with(body: { token: "T" }.to_json).to_return(reply({ data: { orderId: 3 } }))
    expect(client.cards.charge(token: "T")).to eq(3)

    stub_request(:post, "#{base}/card/chargeWith3ds").to_return(reply({ data: { orderId: 4, redirectUrl: "https://3ds" } }, status: 201))
    expect(client.cards.charge_with_3ds(token: "T")).to eq(order_id: 4, redirect_url: "https://3ds")
  end

  it "maps snake_case register extras to camelCase" do
    stub = stub_request(:post, "#{base}/transaction/register").with { |req|
      body = JSON.parse(req.body)
      body["methodRefId"] == "REF" && body["additional"] == { "PSU" => { "IP" => "1.1.1.1", "userAgent" => "UA" } }
    }.to_return(reply({ data: { token: "TOK" } }))

    client.transactions.register(session_id: "S", amount: 100, currency: "PLN", description: "d", email: "a@b.pl",
                                 url_return: "https://r", url_status: "https://s", method_ref_id: "REF",
                                 additional: { PSU: { IP: "1.1.1.1", userAgent: "UA" } })
    expect(stub).to have_been_requested
  end
end
