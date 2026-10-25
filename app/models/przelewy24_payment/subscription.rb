# frozen_string_literal: true

module Przelewy24Payment
  # Przelewy24 has no subscription object: it only lets you charge a stored
  # BLIK alias or card reference without the customer present. This model keeps
  # the schedule on your side and drives those charges.
  #
  #   pending   -> first payment not confirmed yet
  #   active    -> charged every `frequency` while payments succeed
  #   past_due  -> last charge failed, retried every config.retry_interval
  #   canceled  -> no more charges (by you, or after too many failures)
  class Subscription < ApplicationRecord
    self.table_name = "przelewy24_subscriptions"

    STATUSES = %w[pending active past_due canceled].freeze
    METHODS = %w[blik card].freeze
    FREQUENCY = /\A([1-9]\d{0,2})([DWMY])\z/

    include Payable

    belongs_to :owner, polymorphic: true

    validates :payment_method, inclusion: { in: METHODS }
    validates :status, inclusion: { in: STATUSES }
    validates :frequency, format: { with: FREQUENCY }
    validates :amount, numericality: { only_integer: true, greater_than: 0 }
    validates :currency, :email, :return_url, presence: true

    scope :active, -> { where(status: "active") }
    scope :due, ->(at = Time.current) { where(status: %w[active past_due]).where(next_charge_at: ..at) }

    # Starts a subscription with its first payment, made with the customer
    # present. Redirect to the returned payment's redirect_url (card, or BLIK
    # through the gateway) or complete a BLIK code payment with
    # payment.charge_blik_code!(...) passing the same alias and `recurring`.
    #
    # For BLIK pass `recurring:` exactly as described in the Przelewy24 docs
    # (type O/M/A, frequency, limits). The feature must be enabled by Przelewy24.
    #
    # psu: { IP:, userAgent: } of the customer; Przelewy24 requires it for BLIK
    # and it is reused for later off-session charges.
    def self.start!(owner:, payment_method:, amount:, currency:, email:, description:, frequency:, return_url:,
                    psu: nil, recurring: nil, alias_value: nil, alias_label: nil, client: Przelewy24Payment.client,
                    **payment_options)
      is_blik = payment_method.to_s == "blik"
      subscription = create!(owner: owner, payment_method: payment_method.to_s, amount: Money.to_minor(amount),
                             currency: currency, email: email, description: description, frequency: frequency,
                             return_url: return_url, psu: psu, recurring: recurring,
                             alias_value: alias_value || (SecureRandom.uuid if is_blik),
                             alias_label: alias_label || description.to_s.ljust(5, ".").first(35))
      payment_options[:additional] = { PSU: psu } if psu
      subscription.first_payment = Payment.start!(
        payable: subscription, amount: amount, currency: currency, email: email, description: description,
        return_url: return_url, client: client, **payment_options
      )
      subscription
    rescue StandardError
      subscription&.update_columns(status: "canceled", cancel_reason: "start_failed")
      raise
    end

    attr_accessor :first_payment

    # Charges the stored method for the next period. The result arrives through
    # the normal status webhook, which renews the subscription.
    # Returns the pending Payment, or nil when a charge is already in flight.
    def charge!(client: Przelewy24Payment.client)
      payment = with_lock do
        next if canceled? || method_ref.blank? || przelewy24_payments.pending.exists?

        Payment.create_for!(self)
      end
      return unless payment

      payment.register_and_charge!(client: client)
      payment
    rescue Error => e
      record_failure!(reason: e.message)
      nil
    end

    # Charges every due subscription. Run from a recurring job.
    def self.charge_due!(client: Przelewy24Payment.client)
      due.find_each.count { |subscription| subscription.charge!(client: client) }
    end

    def cancel!(reason: "canceled")
      return false if canceled?

      update!(status: "canceled", canceled_at: Time.current, cancel_reason: reason, next_charge_at: nil)
      Instrumentation.instrument("subscription_canceled", subscription: self)
      true
    end

    def canceled? = status == "canceled"
    def active? = status == "active"
    def amount_decimal = Money.from_minor(amount)

    # Called from Payment#settle! when a payment of this subscription is verified.
    def payment_verified!(payment, client: Przelewy24Payment.client)
      return if canceled?

      first = pending?
      self.method_ref = fetch_card_reference(payment, client) if payment_method == "card" && method_ref.blank?
      self.method_ref = alias_value if payment_method == "blik" && method_ref.blank?
      update!(status: "active", failed_attempts: 0, last_charged_at: Time.current,
              next_charge_at: advance(Time.current))
      Instrumentation.instrument(first ? "subscription_activated" : "subscription_renewed",
                                 subscription: self, payment: payment)
    end

    # Called when a payment of this subscription failed or expired.
    def record_failure!(reason: nil)
      return if canceled?

      attempts = failed_attempts + 1
      if pending? || attempts >= Przelewy24Payment.configuration.max_failed_attempts
        return cancel!(reason: reason.presence || "payment_failed")
      end

      update!(status: "past_due", failed_attempts: attempts,
              next_charge_at: Przelewy24Payment.configuration.retry_interval.from_now)
      Instrumentation.instrument("subscription_past_due", subscription: self, reason: reason)
    end

    def pending? = status == "pending"

    private

    def advance(from)
      count, unit = FREQUENCY.match(frequency).captures
      count = count.to_i
      case unit
      when "D" then from + count.days
      when "W" then from + count.weeks
      when "M" then from + count.months
      when "Y" then from + count.years
      end
    end

    def fetch_card_reference(payment, client)
      client.cards.reference_for(payment.p24_order_id)
    end

    ActiveSupport.run_load_hooks(:przelewy24_payment_subscription, self)
  end
end
