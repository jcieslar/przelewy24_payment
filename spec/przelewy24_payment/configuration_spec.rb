# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Configuration do
  subject(:config) { described_class.new }

  around do |example|
    keys = %w[PRZELEWY24_MERCHANT_ID PRZELEWY24_POS_ID PRZELEWY24_API_KEY PRZELEWY24_CRC_KEY PRZELEWY24_ENVIRONMENT]
    saved = ENV.values_at(*keys)
    keys.each { |k| ENV.delete(k) }
    example.run
    keys.zip(saved).each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  it "defaults to sandbox" do
    expect(config).to be_sandbox
    expect(config.api_url).to eq("https://sandbox.przelewy24.pl/api/v1")
  end

  it "uses production hosts" do
    config.environment = :production
    expect(config.gateway_url("tok")).to eq("https://secure.przelewy24.pl/trnRequest/tok")
  end

  it "rejects unknown environments" do
    expect { config.environment = :staging }.to raise_error(Przelewy24Payment::ConfigurationError)
  end

  it "reads credentials from ENV" do
    ENV["PRZELEWY24_MERCHANT_ID"] = "42"
    ENV["PRZELEWY24_API_KEY"] = "k"
    ENV["PRZELEWY24_CRC_KEY"] = "c"
    expect([ config.merchant_id, config.pos_id, config.api_key, config.crc_key ]).to eq([ 42, 42, "k", "c" ])
  end

  it "prefers explicit values and a separate pos id" do
    ENV["PRZELEWY24_MERCHANT_ID"] = "1"
    config.merchant_id = 2
    config.pos_id = 3
    expect([ config.merchant_id, config.pos_id ]).to eq([ 2, 3 ])
  end

  it "names every missing credential" do
    expect { config.merchant_id }.to raise_error(
      Przelewy24Payment::ConfigurationError, /PRZELEWY24_MERCHANT_ID.*PRZELEWY24_API_KEY.*PRZELEWY24_CRC_KEY/
    )
  end
end
