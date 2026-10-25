# frozen_string_literal: true

module Przelewy24Payment
  module Api
    class Base
      def initialize(client)
        @client = client
      end

      private

      attr_reader :client

      def config = client.configuration
    end
  end
end
