# frozen_string_literal: true

require "faraday"

module Przelewy24Payment
  class Client
    attr_reader :configuration

    def initialize(configuration = Przelewy24Payment.configuration)
      @configuration = configuration
    end

    def test_access
      get("testAccess").dig("data") == true
    end

    def transactions = @transactions ||= Api::Transactions.new(self)
    def refunds = @refunds ||= Api::Refunds.new(self)
    def payment_methods = @payment_methods ||= Api::PaymentMethods.new(self)
    def blik = @blik ||= Api::Blik.new(self)
    def cards = @cards ||= Api::Cards.new(self)

    def get(path, params = nil) = request(:get, path, params)
    def post(path, body) = request(:post, path, body)
    def put(path, body) = request(:put, path, body)

    private

    def request(verb, path, payload)
      configuration.validate!
      response = Instrumentation.instrument("request", verb: verb, path: path) do
        connection.public_send(verb, path, payload)
      end
      handle(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
      raise ConnectionError, "#{e.class}: #{e.message}"
    end

    def handle(response)
      return response.body || {} if response.success?

      body = response.body
      message = body.is_a?(Hash) ? body["error"] : nil
      message = message["message"] if message.is_a?(Hash)
      error_class = case response.status
      when 400, 422 then ValidationError
      when 401, 403 then AuthenticationError
      when 404 then NotFoundError
      when 409 then ConflictError
      when 500.. then ServerError
      else ApiError
      end
      raise error_class.new(message ? "Przelewy24: #{message}" : nil, status: response.status, body: body)
    end

    def connection
      @connection ||= Faraday.new(url: "#{configuration.api_url}/") do |conn|
        conn.request :authorization, :basic, configuration.pos_id.to_s, configuration.api_key
        conn.request :json
        conn.response :json, content_type: /\bjson/
        conn.options.open_timeout = configuration.open_timeout
        conn.options.timeout = configuration.timeout
      end
    end
  end
end
