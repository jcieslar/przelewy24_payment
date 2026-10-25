# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Notification do
  let(:payment) { Struct.new(:session_id, :amount, :currency).new("S1", 1000, "PLN") }
  let(:payload) { Przelewy24Payment::TestHelpers.status_payload(payment) }

  it "accepts a correctly signed payload" do
    notification = described_class.new(payload).verify!
    expect([ notification.session_id, notification.order_id, notification.amount, notification.method_id ]).to eq([ "S1", 123_456, 1000, 25 ])
  end

  it "accepts symbol keys and string numbers" do
    expect(described_class.new(payload.transform_keys(&:to_sym).transform_values(&:to_s))).to be_valid
  end

  it "rejects tampered payloads" do
    expect { described_class.new(payload.merge("amount" => 1)).verify! }.to raise_error(Przelewy24Payment::SignatureError)
  end

  it "rejects another merchant" do
    other = payload.merge("merchantId" => 999)
    other["sign"] = Przelewy24Payment::Signature.notification(other, crc: "crc-key")
    expect(described_class.new(other)).not_to be_valid
  end

  it "rejects incomplete payloads" do
    expect { described_class.new(payload.except("sign")).verify! }.to raise_error(Przelewy24Payment::InvalidNotificationError)
  end

  it "rejects malformed JSON" do
    expect { described_class.from_json("{") }.to raise_error(Przelewy24Payment::InvalidNotificationError)
  end
end
