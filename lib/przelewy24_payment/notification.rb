# frozen_string_literal: true

module Przelewy24Payment
  # A signed transaction status notification sent by Przelewy24 to urlStatus.
  class Notification
    REQUIRED = %w[merchantId posId sessionId amount currency orderId sign].freeze

    attr_reader :attributes

    def initialize(attributes, configuration: Przelewy24Payment.configuration)
      @attributes = attributes.to_h.transform_keys(&:to_s)
      @configuration = configuration
    end

    def self.from_json(raw, **options)
      new(JSON.parse(raw), **options)
    rescue JSON::ParserError => e
      raise InvalidNotificationError, "malformed JSON: #{e.message}"
    end

    def session_id = attributes["sessionId"].to_s
    def order_id = Integer(attributes["orderId"])
    def amount = Integer(attributes["amount"])
    def currency = attributes["currency"].to_s
    def method_id = attributes["methodId"]&.then { |value| Integer(value) }
    def statement = attributes["statement"]

    def complete?
      REQUIRED.all? { |key| attributes[key].to_s != "" }
    end

    def valid?
      complete? &&
        Integer(attributes["merchantId"]) == configuration.merchant_id &&
        Signature.secure_compare?(expected_sign, attributes["sign"])
    rescue ArgumentError, TypeError
      false
    end

    def verify!
      raise InvalidNotificationError, "missing required fields" unless complete?
      raise SignatureError, "invalid notification signature" unless valid?

      self
    end

    private

    attr_reader :configuration

    def expected_sign
      Signature.notification(attributes, crc: configuration.crc_key)
    end
  end
end
