# frozen_string_literal: true

module Przelewy24Payment
  module Api
    class PaymentMethods < Base
      def list(lang: config.default_language)
        client.get("payment/methods/#{lang}").fetch("data")
      end
    end
  end
end
