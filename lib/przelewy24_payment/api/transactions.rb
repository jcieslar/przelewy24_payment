# frozen_string_literal: true

module Przelewy24Payment
  module Api
    class Transactions < Base
      # Registers a transaction and returns its token. Amount is in minor units.
      # Extra keyword arguments are sent as-is in camelCase, e.g. method_ref_id:,
      # method:, additional: { PSU: { IP:, userAgent: } }, transfer_label:,
      # url_card_payment_notification:, time_limit:, wait_for_result:.
      def register(session_id:, amount:, currency:, description:, email:, url_return:, url_status:, **extra)
        body = {
          merchantId: config.merchant_id,
          posId: config.pos_id,
          sessionId: session_id,
          amount: amount,
          currency: currency,
          description: description,
          email: email,
          country: config.default_country,
          language: config.default_language,
          urlReturn: url_return,
          urlStatus: url_status,
          sign: Signature.register(session_id: session_id, merchant_id: config.merchant_id,
                                   amount: amount, currency: currency, crc: config.crc_key)
        }.merge(extra.transform_keys { |key| key.to_s.camelize(:lower).to_sym })

        client.post("transaction/register", body).fetch("data").fetch("token")
      end

      # Confirms a transaction after a status notification. Required for settlement.
      def verify(session_id:, order_id:, amount:, currency:)
        body = {
          merchantId: config.merchant_id,
          posId: config.pos_id,
          sessionId: session_id,
          amount: amount,
          currency: currency,
          orderId: order_id,
          sign: Signature.verify(session_id: session_id, order_id: order_id, amount: amount,
                                 currency: currency, crc: config.crc_key)
        }

        client.put("transaction/verify", body).dig("data", "status") == "success"
      end

      def find_by_session_id(session_id)
        client.get("transaction/by/sessionId/#{ERB::Util.url_encode(session_id)}").fetch("data")
      end
    end
  end
end
