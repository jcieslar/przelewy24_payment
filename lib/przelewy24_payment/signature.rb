# frozen_string_literal: true

require "digest"
require "json"

module Przelewy24Payment
  # Przelewy24 signs the compact JSON of an ordered hash with SHA-384.
  # Key order is part of the contract, so every endpoint has its own builder.
  module Signature
    module_function

    def register(session_id:, merchant_id:, amount:, currency:, crc:)
      sign("sessionId" => session_id.to_s, "merchantId" => Integer(merchant_id),
           "amount" => Integer(amount), "currency" => currency.to_s, "crc" => crc.to_s)
    end

    def verify(session_id:, order_id:, amount:, currency:, crc:)
      sign("sessionId" => session_id.to_s, "orderId" => Integer(order_id),
           "amount" => Integer(amount), "currency" => currency.to_s, "crc" => crc.to_s)
    end

    # Optional fields are signed only when Przelewy24 sends them, in the
    # order below.
    def notification(attrs, crc:)
      fields = {}
      fields["merchantId"] = Integer(attrs.fetch("merchantId"))
      fields["posId"] = Integer(attrs.fetch("posId"))
      fields["sessionId"] = attrs.fetch("sessionId").to_s
      fields["amount"] = Integer(attrs.fetch("amount"))
      fields["originAmount"] = Integer(attrs["originAmount"]) if present?(attrs["originAmount"])
      fields["currency"] = attrs.fetch("currency").to_s
      fields["orderId"] = Integer(attrs.fetch("orderId"))
      fields["methodId"] = Integer(attrs["methodId"]) if present?(attrs["methodId"])
      fields["statement"] = attrs["statement"].to_s if present?(attrs["statement"])
      fields["crc"] = crc.to_s
      sign(fields)
    end

    def refund_notification(attrs, crc:)
      sign("orderId" => Integer(attrs.fetch("orderId")),
           "sessionId" => attrs.fetch("sessionId").to_s,
           "refundsUuid" => attrs.fetch("refundsUuid").to_s,
           "merchantId" => Integer(attrs.fetch("merchantId")),
           "amount" => Integer(attrs.fetch("amount")),
           "currency" => attrs.fetch("currency").to_s,
           "status" => Integer(attrs.fetch("status")),
           "crc" => crc.to_s)
    end

    def sign(fields)
      Digest::SHA384.hexdigest(JSON.generate(fields))
    end

    def present?(value)
      !value.nil? && value.to_s != ""
    end

    def secure_compare?(expected, actual)
      return false unless actual.is_a?(String) && actual.bytesize == expected.bytesize

      OpenSSL.fixed_length_secure_compare(expected, actual)
    end
  end
end
