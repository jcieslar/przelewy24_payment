# frozen_string_literal: true

module Przelewy24Payment
  # Include in any model that can be paid for (Order, Invoice, ...).
  module Payable
    extend ActiveSupport::Concern

    included do
      has_many :przelewy24_payments, as: :payable, class_name: "Przelewy24Payment::Payment", dependent: :restrict_with_exception
    end

    def przelewy24_paid?
      przelewy24_payments.verified.exists?
    end

    def latest_przelewy24_payment
      przelewy24_payments.order(:id).last
    end
  end
end
