# frozen_string_literal: true

require "rails"
require "action_controller/railtie"
require "active_record/railtie"
require "przelewy24_payment"

module Dummy
  class Application < Rails::Application
    config.load_defaults Rails::VERSION::STRING.to_f
    config.root = File.expand_path("..", __dir__)
    config.eager_load = false
    config.secret_key_base = "test"
    config.hosts.clear
    config.logger = Logger.new(nil)
    config.active_support.deprecation = :stderr
  end
end
