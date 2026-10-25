# frozen_string_literal: true

module Przelewy24Payment
  class Engine < ::Rails::Engine
    isolate_namespace Przelewy24Payment

    initializer "przelewy24_payment.filter_parameters" do |app|
      app.config.filter_parameters += %i[sign crc crc_key api_key]
    end

    generators do
      require "generators/przelewy24_payment/install/install_generator"
    end
  end
end
