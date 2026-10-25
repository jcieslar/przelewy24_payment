# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Signature do
  def sha384(json) = Digest::SHA384.hexdigest(json)

  it "signs registration in P24 key order" do
    expected = sha384('{"sessionId":"abc","merchantId":12345,"amount":1000,"currency":"PLN","crc":"k"}')
    expect(described_class.register(session_id: "abc", merchant_id: 12_345, amount: 1000, currency: "PLN", crc: "k")).to eq(expected)
  end

  it "signs verification in P24 key order" do
    expected = sha384('{"sessionId":"abc","orderId":99,"amount":1000,"currency":"PLN","crc":"k"}')
    expect(described_class.verify(session_id: "abc", order_id: 99, amount: 1000, currency: "PLN", crc: "k")).to eq(expected)
  end

  it "signs notifications, skipping absent optional fields and coercing types" do
    attrs = { "merchantId" => "1", "posId" => "1", "sessionId" => "s", "amount" => "100", "currency" => "PLN", "orderId" => "7" }
    expected = sha384('{"merchantId":1,"posId":1,"sessionId":"s","amount":100,"currency":"PLN","orderId":7,"crc":"k"}')
    expect(described_class.notification(attrs, crc: "k")).to eq(expected)
  end

  it "does not escape slashes or unicode" do
    expect(described_class.sign("a" => "/ż")).to eq(sha384('{"a":"/ż"}'))
  end

  it "compares signatures safely" do
    expect(described_class.secure_compare?("abc", "abc")).to be true
    expect(described_class.secure_compare?("abc", "abd")).to be false
    expect(described_class.secure_compare?("abc", nil)).to be false
  end
end
