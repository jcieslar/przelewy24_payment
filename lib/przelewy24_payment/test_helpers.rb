# frozen_string_literal: true

module Przelewy24Payment
  # Builds signed webhook payloads for host-app specs.
  #   post przelewy24_payment.status_webhooks_path,
  #        params: Przelewy24Payment::TestHelpers.status_payload(payment), as: :json
  module TestHelpers
    module_function

    def status_payload(payment, order_id: 123_456, method_id: 25, configuration: Przelewy24Payment.configuration)
      attrs = {
        "merchantId" => configuration.merchant_id, "posId" => configuration.pos_id,
        "sessionId" => payment.session_id, "amount" => payment.amount,
        "originAmount" => payment.amount, "currency" => payment.currency,
        "orderId" => order_id, "methodId" => method_id, "statement" => "p24-#{order_id}"
      }
      attrs.merge("sign" => Signature.notification(attrs, crc: configuration.crc_key))
    end
  end
end
