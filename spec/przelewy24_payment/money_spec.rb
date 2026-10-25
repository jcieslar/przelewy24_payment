# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Money do
  it "converts decimals without float drift" do
    expect(described_class.to_minor(BigDecimal("19.99"))).to eq(1999)
    expect(described_class.to_minor("0.29")).to eq(29)
    expect(described_class.to_minor(19.99)).to eq(1999)
    expect(described_class.to_minor(10)).to eq(1000)
  end

  it "converts back" do
    expect(described_class.from_minor(1999)).to eq(BigDecimal("19.99"))
  end

  it "rejects unsupported types" do
    expect { described_class.to_minor(nil) }.to raise_error(ArgumentError)
  end
end
