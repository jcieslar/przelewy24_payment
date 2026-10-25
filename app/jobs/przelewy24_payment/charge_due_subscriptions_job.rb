# frozen_string_literal: true

module Przelewy24Payment
  # Schedule this job (cron, Solid Queue recurring tasks, GoodJob cron) e.g. hourly.
  class ChargeDueSubscriptionsJob < ApplicationJob
    queue_as :default

    def perform
      Subscription.charge_due!
      Payment.expire_stale!
    end
  end
end
