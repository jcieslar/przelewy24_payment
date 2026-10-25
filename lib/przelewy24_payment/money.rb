# frozen_string_literal: true

require "bigdecimal"

module Przelewy24Payment
  # Converts between decimal amounts and the integer minor units
  # (grosze, cents) that Przelewy24 expects.
  module Money
    module_function

    def to_minor(amount)
      case amount
      when Integer then amount * 100
      when BigDecimal then (amount * 100).round(0, :half_up).to_i
      when String, Rational then (BigDecimal(amount.to_s) * 100).round(0, :half_up).to_i
      when Float then (BigDecimal(amount.to_s) * 100).round(0, :half_up).to_i
      else
        raise ArgumentError, "unsupported amount: #{amount.inspect}"
      end
    end

    def from_minor(minor)
      BigDecimal(Integer(minor)) / 100
    end
  end
end
