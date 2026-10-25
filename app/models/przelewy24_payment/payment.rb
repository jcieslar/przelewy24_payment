# frozen_string_literal: true

module Przelewy24Payment
  class Payment < ApplicationRecord
    self.table_name = "przelewy24_payments"

    # pending:  registered, waiting for the customer or for a notification
    # verified: confirmed by Przelewy24, money received
    # failed:   notification arrived but verification was rejected
    # expired:  abandoned attempt closed by .expire_stale!; a late notification
    #           can still settle it
    STATUSES = %w[pending verified failed expired].freeze

    belongs_to :payable, polymorphic: true
    has_many :refunds, class_name: "Przelewy24Payment::Refund", dependent: :destroy

    validates :session_id, presence: true, uniqueness: true
    validates :amount, numericality: { only_integer: true, greater_than: 0 }
    validates :currency, presence: true
    validates :status, inclusion: { in: STATUSES }

    scope :pending, -> { where(status: "pending") }
    scope :verified, -> { where(status: "verified") }
    scope :stale, ->(older_than: 1.day) { pending.where(created_at: ...older_than.ago) }

    # Creates a payment with a fresh session id, registers it at Przelewy24
    # and returns it with a token. Each payment attempt gets its own record.
    # Closes abandoned attempts (customer left the gateway, no notification came).
    # Safe to run from a recurring job; returns the number of closed payments.
    def self.expire_stale!(older_than: 1.day)
      stale(older_than: older_than).find_each.count(&:expire!)
    end

    # Builds the pending payment for the next period of a subscription.
    def self.create_for!(subscription)
      create!(payable: subscription, amount: subscription.amount, currency: subscription.currency,
              session_id: SecureRandom.alphanumeric(16).upcase)
    end

    # Raises AlreadyPaidError when the payable already has a verified payment,
    # so a retry can never charge the customer twice.
    def self.start!(payable:, amount:, currency:, email:, description:, return_url:, status_url: nil,
                    client: Przelewy24Payment.client, **extra)
      raise AlreadyPaidError, "#{payable.class} ##{payable.id} already has a verified payment" if payable.przelewy24_paid?

      payment = create!(payable: payable, amount: Money.to_minor(amount), currency: currency,
                        session_id: SecureRandom.alphanumeric(16).upcase)
      token = client.transactions.register(
        session_id: payment.session_id, amount: payment.amount, currency: currency,
        description: description, email: email, url_return: return_url,
        url_status: status_url || payment.default_status_url, **extra
      )
      payment.update!(token: token)
      payment
    rescue StandardError
      payment&.update_columns(status: "failed")
      raise
    end

    def amount_decimal = Money.from_minor(amount)

    def subscription
      payable if payable.is_a?(Subscription)
    end

    # Closes an abandoned attempt. For a subscription this counts as a failed charge.
    def expire!
      with_lock do
        next false unless status == "pending"

        update!(status: "expired")
        subscription&.record_failure!(reason: "payment_expired")
        true
      end
    end

    # BLIK level 0: charges the registered transaction with the customer's code.
    # For a subscription payment the alias and recurring settings default to the
    # ones stored on the subscription. The result arrives through the webhook.
    def charge_blik_code!(blik_code:, alias_value: nil, alias_label: nil, recurring: nil,
                          client: Przelewy24Payment.client)
      sub = subscription
      client.blik.charge_by_code(
        token: token, blik_code: blik_code,
        alias_value: alias_value || sub&.alias_value, alias_label: alias_label || sub&.alias_label,
        recurring: recurring || sub&.recurring
      )
    end

    # BLIK 1-click with a stored alias.
    def charge_blik_alias!(alias_value:, client: Przelewy24Payment.client)
      client.blik.charge_by_alias(token: token, alias_value: alias_value)
    end

    # Card charge by reference (registered with method_ref_id). Without 3-D Secure
    # it is off-session; with `three_ds: true` it returns { order_id:, redirect_url: }.
    def charge_card!(three_ds: false, client: Przelewy24Payment.client)
      three_ds ? client.cards.charge_with_3ds(token: token) : client.cards.charge(token: token)
    end

    # Registers and charges a subscription renewal without the customer.
    def register_and_charge!(client: Przelewy24Payment.client)
      sub = subscription
      options = { method_ref_id: sub.method_ref }
      options[:additional] = { PSU: sub.psu } if sub.payment_method == "blik" && sub.psu
      self.token = client.transactions.register(
        session_id: session_id, amount: amount, currency: currency, description: sub.description,
        email: sub.email, url_return: sub.return_url, url_status: default_status_url, **options
      )
      save!
      if sub.payment_method == "blik"
        charge_blik_alias!(alias_value: sub.method_ref, client: client)
      else
        charge_card!(client: client)
      end
    rescue StandardError
      update_columns(status: "failed") if persisted?
      raise
    end

    def redirect_url = token && Przelewy24Payment.configuration.gateway_url(token)
    def pending? = status == "pending"
    def expired? = status == "expired"
    def verified? = status == "verified"
    def failed? = status == "failed"

    def default_status_url
      Przelewy24Payment::Engine.routes.url_helpers.status_webhooks_url(
        **Przelewy24Payment.configuration.url_options
      )
    end

    # Verifies the notification with Przelewy24 exactly once: row lock + status
    # guard make duplicate deliveries harmless. Does not run callbacks, see
    # #deliver_callbacks!. Returns :verified, :failed or :duplicate.
    def settle!(notification, client: Przelewy24Payment.client)
      with_lock do
        next :duplicate unless status.in?(%w[pending expired])

        update!(p24_order_id: notification.order_id, method_id: notification.method_id,
                payload: notification.attributes.except("sign"))
        ok = client.transactions.verify(session_id: session_id, order_id: notification.order_id,
                                        amount: amount, currency: currency)
        update!(status: ok ? "verified" : "failed", verified_at: (Time.current if ok))
        if ok
          subscription&.payment_verified!(self, client: client)
        else
          subscription&.record_failure!(reason: "verification_failed")
        end
        ok ? :verified : :failed
      end
    end

    def settled? = status.in?(%w[verified failed])

    # Runs the configured callback for a settled payment until it succeeds once.
    # The callback and the notified_at stamp share one transaction, so a raising
    # callback leaves the payment un-notified and the next webhook delivery
    # retries it. Callbacks therefore run at least once and must be idempotent
    # for side effects outside the database (mails, jobs).
    # Returns true when the callback ran, false when there was nothing to do.
    def deliver_callbacks!
      with_lock do
        next false unless settled? && notified_at.nil?

        config = Przelewy24Payment.configuration
        callback = verified? ? config.on_payment_verified : config.on_payment_failed
        callback&.call(self)
        update!(notified_at: Time.current)
        Instrumentation.instrument("payment_#{status}", payment: self)
        true
      end
    end

    ActiveSupport.run_load_hooks(:przelewy24_payment_payment, self)
  end
end
