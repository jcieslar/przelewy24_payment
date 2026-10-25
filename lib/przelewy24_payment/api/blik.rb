# frozen_string_literal: true

module Przelewy24Payment
  module Api
    # BLIK on the merchant's own page. The transaction must be registered first
    # (with additional.PSU) and its token passed here.
    class Blik < Base
      # BLIK level 0: the customer types the 6-digit code. Pass alias_value,
      # alias_label (5..35 chars) and recurring to register an alias for later charges.
      def charge_by_code(token:, blik_code:, alias_value: nil, alias_label: nil, recurring: nil)
        body = { token: token, blikCode: blik_code, aliasValue: alias_value,
                 aliasLabel: alias_label, recurring: recurring }.compact
        client.post("paymentMethod/blik/chargeByCode", body).fetch("data").fetch("orderId")
      end

      # BLIK 1-click / recurring charge with a stored alias. Raises
      # AmbiguousAliasError (HTTP 409) when the alias maps to several bank apps;
      # retry with charge_by_alternative_key using one of error.alternative_keys.
      def charge_by_alias(token:, alias_value:)
        charge(type: "alias", token: token, aliasValue: alias_value)
      end

      def charge_by_alternative_key(token:, alternative_key:)
        charge(type: "alternativeKey", token: token, alternativeKey: alternative_key)
      end

      def aliases(email, custom: false)
        path = "paymentMethod/blik/getAliasesByEmail/#{ERB::Util.url_encode(email)}"
        client.get(custom ? "#{path}/custom" : path).fetch("data")
      end

      private

      def charge(body)
        client.post("paymentMethod/blik/chargeByAlias", body).fetch("data").fetch("orderId")
      rescue ConflictError => e
        raise AmbiguousAliasError.new(e.message, status: e.status, body: e.body)
      end
    end
  end
end
