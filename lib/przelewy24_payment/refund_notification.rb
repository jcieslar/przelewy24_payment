# frozen_string_literal: true

module Przelewy24Payment
  # A signed refund status notification. Status 0 means the refund was
  # completed, 1 means it was rejected.
  class RefundNotification
    REQUIRED = %w[orderId sessionId refundsUuid merchantId amount currency status sign].freeze

    attr_reader :attributes

    def initialize(attributes, configuration: Przelewy24Payment.configuration)
      @attributes = attributes.to_h.transform_keys(&:to_s)
      @configuration = configuration
    end

    def refunds_uuid = attributes["refundsUuid"].to_s
    def session_id = attributes["sessionId"].to_s
    def order_id = Integer(attributes["orderId"])
    def amount = Integer(attributes["amount"])
    def success? = Integer(attributes["status"]).zero?

    def complete?
      REQUIRED.all? { |key| attributes[key].to_s != "" }
    end

    def valid?
      complete? &&
        Signature.secure_compare?(Signature.refund_notification(attributes, crc: configuration.crc_key), attributes["sign"])
    rescue ArgumentError, TypeError
      false
    end

    def verify!
      raise InvalidNotificationError, "missing required fields" unless complete?
      raise SignatureError, "invalid refund notification signature" unless valid?

      self
    end

    private

    attr_reader :configuration
  end
end
