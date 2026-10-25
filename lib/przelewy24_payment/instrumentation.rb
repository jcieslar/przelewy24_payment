# frozen_string_literal: true

require "active_support/notifications"

module Przelewy24Payment
  # Events are published as "<name>.przelewy24", e.g. "request.przelewy24".
  module Instrumentation
    NAMESPACE = "przelewy24"

    module_function

    def instrument(name, payload = {}, &block)
      ActiveSupport::Notifications.instrument("#{name}.#{NAMESPACE}", payload, &block)
    end
  end
end
