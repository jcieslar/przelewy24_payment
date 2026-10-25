# frozen_string_literal: true

module Przelewy24Payment
  module Api
    # Card one-click and recurring charges by card reference (refId). The
    # reference must be passed as methodRefId when registering the transaction.
    class Cards < Base
      # Reference of the card used in a paid transaction (nil when unavailable).
      def reference_for(order_id)
        client.get("card/info/#{Integer(order_id)}").dig("data", "refId")
      end

      # Charge without the customer present (recurring). Returns the order id.
      def charge(token:)
        client.post("card/charge", { token: token }).fetch("data").fetch("orderId")
      end

      # One-click charge that may need 3-D Secure. Returns { order_id:, redirect_url: }
      # where redirect_url is nil when no customer action is needed.
      def charge_with_3ds(token:)
        data = client.post("card/chargeWith3ds", { token: token }).fetch("data")
        { order_id: data["orderId"], redirect_url: data["redirectUrl"] }
      end
    end
  end
end
