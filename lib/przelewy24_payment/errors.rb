# frozen_string_literal: true

module Przelewy24Payment
  class Error < StandardError; end

  # Raised when a required setting is missing or invalid.
  class ConfigurationError < Error; end

  # Raised for transport-level failures (timeouts, DNS, TLS).
  class ConnectionError < Error; end

  # Raised when starting a payment for something that is already paid.
  class AlreadyPaidError < Error; end

  # Raised when a webhook signature does not match.
  class SignatureError < Error; end

  # Raised when a webhook payload lacks required fields.
  class InvalidNotificationError < Error; end

  # Raised when Przelewy24 answers with an error status.
  class ApiError < Error
    attr_reader :status, :body

    def initialize(message = nil, status: nil, body: nil)
      @status = status
      @body = body
      super(message || "Przelewy24 API error (HTTP #{status})")
    end
  end

  class AuthenticationError < ApiError; end
  class ValidationError < ApiError; end
  class NotFoundError < ApiError; end
  class ServerError < ApiError; end

  class ConflictError < ApiError; end

  # BLIK chargeByAlias answered 409: the alias is linked to several bank apps.
  class AmbiguousAliasError < ConflictError
    def alternative_keys
      Array(body.is_a?(Hash) ? body.dig("error", "alternativeKeys") : nil)
    end
  end
end
