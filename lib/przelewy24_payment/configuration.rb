# frozen_string_literal: true

module Przelewy24Payment
  class Configuration
    HOSTS = {
      sandbox: "https://sandbox.przelewy24.pl",
      production: "https://secure.przelewy24.pl"
    }.freeze

    ENV_KEYS = {
      merchant_id: "PRZELEWY24_MERCHANT_ID",
      pos_id: "PRZELEWY24_POS_ID",
      api_key: "PRZELEWY24_API_KEY",
      crc_key: "PRZELEWY24_CRC_KEY"
    }.freeze

    attr_writer :merchant_id, :pos_id, :api_key, :crc_key
    attr_accessor :default_country, :default_language, :url_options,
                  :open_timeout, :timeout, :logger, :allowed_ips,
                  :on_payment_verified, :on_payment_failed, :on_refund,
                  :max_failed_attempts, :retry_interval, :parent_controller
    attr_reader :environment

    def initialize
      self.environment = ENV.fetch("PRZELEWY24_ENVIRONMENT", "sandbox")
      @default_country = "PL"
      @default_language = "pl"
      @url_options = {}
      @open_timeout = 5
      @timeout = 15
      @allowed_ips = nil
      @parent_controller = "ActionController::API"
      @max_failed_attempts = 3
      @retry_interval = 1.day
    end

    def environment=(value)
      value = value.to_s.to_sym
      unless HOSTS.key?(value)
        raise ConfigurationError, "environment must be one of #{HOSTS.keys.inspect}, got #{value.inspect}"
      end

      @environment = value
    end

    def sandbox? = environment == :sandbox
    def production? = environment == :production

    def merchant_id = Integer(fetch!(:merchant_id))
    def pos_id = Integer(value_for(:pos_id).presence || fetch!(:merchant_id))
    def api_key = fetch!(:api_key).to_s
    def crc_key = fetch!(:crc_key).to_s

    def host = HOSTS.fetch(environment)
    def api_url = "#{host}/api/v1"
    def gateway_url(token) = "#{host}/trnRequest/#{token}"

    def logger = @logger || (defined?(::Rails) ? ::Rails.logger : nil)

    # Raises ConfigurationError naming every missing credential at once.
    # Called lazily on first use, so asset precompilation and generators
    # work without credentials.
    def validate!
      missing = ENV_KEYS.keys.reject { |key| key == :pos_id || value_for(key).present? }
      return self if missing.empty?

      names = missing.map { |key| "#{key} (#{ENV_KEYS.fetch(key)})" }
      raise ConfigurationError, "Przelewy24Payment is missing: #{names.join(', ')}"
    end

    private

    def fetch!(key)
      value_for(key).presence || validate!.then { value_for(key) }
    end

    def value_for(key)
      instance_variable_get("@#{key}").presence || ENV[ENV_KEYS.fetch(key)].presence
    end
  end
end
