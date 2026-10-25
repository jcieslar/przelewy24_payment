# frozen_string_literal: true

module Przelewy24Payment
  module Api
    class Refunds < Base
      # Refunds part or all of a verified transaction. Amount is in minor units.
      def create(request_id:, order_id:, session_id:, amount:, url_status:, description: nil)
        refunds_uuid = SecureRandom.uuid
        body = {
          requestId: request_id,
          refunds: [ { orderId: order_id, sessionId: session_id, amount: amount, description: description }.compact ],
          refundsUuid: refunds_uuid,
          urlStatus: url_status
        }

        data = client.post("transaction/refund", body).fetch("data")
        { "refundsUuid" => refunds_uuid, "refunds" => data }
      end

      def find(order_id)
        client.get("refund/by/orderId/#{Integer(order_id)}").fetch("data")
      end
    end
  end
end
