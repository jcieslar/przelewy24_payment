# frozen_string_literal: true

module Przelewy24Payment
  class Refund < ApplicationRecord
    self.table_name = "przelewy24_refunds"

    STATUSES = %w[pending completed failed].freeze

    belongs_to :payment, class_name: "Przelewy24Payment::Payment"

    validates :amount, numericality: { only_integer: true, greater_than: 0 }
    validates :refunds_uuid, presence: true, uniqueness: true
    validates :status, inclusion: { in: STATUSES }

    # Requests a refund of a verified payment. Amount in decimal currency units.
    def self.request!(payment:, amount:, description: nil, status_url: nil, client: Przelewy24Payment.client)
      raise Error, "payment is not verified" unless payment.verified?

      minor = Money.to_minor(amount)
      request_id = SecureRandom.uuid
      result = client.refunds.create(
        request_id: request_id, order_id: payment.p24_order_id, session_id: payment.session_id,
        amount: minor, description: description,
        url_status: status_url || Przelewy24Payment::Engine.routes.url_helpers.refund_webhooks_url(
          **Przelewy24Payment.configuration.url_options
        )
      )
      create!(payment: payment, amount: minor, request_id: request_id, refunds_uuid: result.fetch("refundsUuid"))
    end

    ActiveSupport.run_load_hooks(:przelewy24_payment_refund, self)
  end
end
