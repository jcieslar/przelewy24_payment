# frozen_string_literal: true

require "rails"
require "active_record/railtie"
require "active_job/railtie"
require "securerandom"
require "ipaddr"
require "zeitwerk"

loader = Zeitwerk::Loader.for_gem
loader.ignore("#{__dir__}/generators")
loader.ignore("#{__dir__}/przelewy24_payment/version.rb")
loader.ignore("#{__dir__}/przelewy24_payment/errors.rb")
loader.setup

require_relative "przelewy24_payment/version"
require_relative "przelewy24_payment/errors"

module Przelewy24Payment
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def client
      Client.new(configuration)
    end

    def reset_configuration!
      @configuration = Configuration.new
    end
  end
end

require "przelewy24_payment/engine"
