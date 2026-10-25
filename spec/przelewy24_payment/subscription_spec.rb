# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Subscription do
  let(:base) { "https://sandbox.przelewy24.pl/api/v1" }
  let(:json) { { "Content-Type" => "application/json" } }
  let(:owner) { Order.create! }
  let(:psu) { { IP: "1.2.3.4", userAgent: "UA" } }
  let(:events) { [] }

  def reply(data, status: 200) = { status: status, body: data.to_json, headers: json }

  def stub_register = stub_request(:post, "#{base}/transaction/register").to_return(reply({ data: { token: "TOK" } }))
  def stub_verify(status = "success") = stub_request(:put, "#{base}/transaction/verify").to_return(reply({ data: { status: status } }))
  def stub_alias_charge = stub_request(:post, "#{base}/paymentMethod/blik/chargeByAlias").to_return(reply({ data: { orderId: 5 } }))

  def start(method: "blik", **extra)
    described_class.start!(owner: owner, payment_method: method, amount: BigDecimal("29.00"), currency: "PLN",
                           email: "a@b.pl", description: "Monthly plan", frequency: "1M",
                           return_url: "https://shop.test/back", psu: psu, **extra)
  end

  def settle(payment, order_id: 777)
    notification = Przelewy24Payment::Notification.new(
      Przelewy24Payment::TestHelpers.status_payload(payment, order_id: order_id)
    )
    payment.settle!(notification)
  end

  around do |example|
    ActiveSupport::Notifications.subscribed(->(name, *_) { events << name }, /\.przelewy24\z/) { example.run }
  end

  describe ".start!" do
    it "creates a pending subscription with its first payment, sending the PSU" do
      stub = stub_request(:post, "#{base}/transaction/register").with { |req|
        JSON.parse(req.body).dig("additional", "PSU") == { "IP" => "1.2.3.4", "userAgent" => "UA" }
      }.to_return(reply({ data: { token: "TOK" } }))

      subscription = start(recurring: { type: "M", frequency: "1M" })
      expect(subscription).to be_pending
      expect(subscription.first_payment).to have_attributes(token: "TOK", amount: 2900, payable: subscription)
      expect(subscription.alias_value).to be_present
      expect(subscription.alias_label.length).to be_between(5, 35)
      expect(stub).to have_been_requested
    end

    it "cancels the subscription when registration fails" do
      stub_request(:post, "#{base}/transaction/register").to_return(reply({ error: "bad" }, status: 400))
      expect { start }.to raise_error(Przelewy24Payment::ValidationError)
      expect(described_class.last).to have_attributes(status: "canceled", cancel_reason: "start_failed")
    end

    it "validates the frequency" do
      stub_register
      expect { start(frequency: "monthly") }.to raise_error(ActiveRecord::RecordInvalid, /Frequency/)
    end
  end

  describe "first payment" do
    before do
      stub_register
      stub_verify
    end

    it "activates a BLIK subscription using the registered alias" do
      subscription = start
      expect(settle(subscription.first_payment)).to eq(:verified)

      subscription.reload
      expect(subscription).to be_active
      expect(subscription.method_ref).to eq(subscription.alias_value)
      expect(subscription.next_charge_at).to be_within(1.minute).of(1.month.from_now)
      expect(events).to include("subscription_activated.przelewy24")
    end

    it "stores the card reference of a card subscription" do
      stub_request(:get, "#{base}/card/info/777").to_return(reply({ data: { refId: "CARDREF" } }))
      subscription = start(method: "card")
      settle(subscription.first_payment)
      expect(subscription.reload).to have_attributes(status: "active", method_ref: "CARDREF")
    end

    it "cancels a pending subscription when the first payment is rejected" do
      stub_verify("error")
      subscription = start
      settle(subscription.first_payment)
      expect(subscription.reload).to have_attributes(status: "canceled", cancel_reason: "verification_failed")
    end

    it "can be charged with a BLIK code reusing the stored alias" do
      subscription = start(recurring: { type: "M" })
      stub = stub_request(:post, "#{base}/paymentMethod/blik/chargeByCode").with { |req|
        body = JSON.parse(req.body)
        body.values_at("blikCode", "aliasValue", "recurring") == [ "777123", subscription.alias_value, { "type" => "M" } ]
      }.to_return(reply({ data: { orderId: 9 } }))

      expect(subscription.first_payment.charge_blik_code!(blik_code: "777123")).to eq(9)
      expect(stub).to have_been_requested
    end
  end

  describe "renewals" do
    let(:subscription) do
      stub_register
      stub_verify
      start.tap { |s| settle(s.first_payment) }.reload
    end

    it "charges the stored BLIK alias and renews on verification" do
      subscription
      stub_alias_charge
      register = stub_register

      payment = subscription.charge!
      expect(payment).to be_pending
      expect(payment.payable).to eq(subscription)
      expect(register).to have_been_requested.at_least_once
      expect(subscription.charge!).to be_nil # already in flight

      subscription.update!(next_charge_at: 1.day.ago)
      settle(payment, order_id: 888)
      expect(subscription.reload).to be_active
      expect(subscription.next_charge_at).to be > 20.days.from_now
      expect(events).to include("subscription_renewed.przelewy24")
    end

    it "charges a card without the customer" do
      stub_register
      stub_verify
      stub_request(:get, "#{base}/card/info/777").to_return(reply({ data: { refId: "CARDREF" } }))
      card = start(method: "card").tap { |s| settle(s.first_payment) }.reload
      register = stub_request(:post, "#{base}/transaction/register").with { |req| JSON.parse(req.body)["methodRefId"] == "CARDREF" }
                                                                     .to_return(reply({ data: { token: "T2" } }))
      charge = stub_request(:post, "#{base}/card/charge").to_return(reply({ data: { orderId: 6 } }))

      expect(card.charge!).to be_pending
      expect([ register, charge ]).to all(have_been_requested)
    end

    it "marks the subscription past due, then cancels it after too many failures" do
      subscription
      stub_request(:post, "#{base}/paymentMethod/blik/chargeByAlias").to_return(reply({ error: "declined" }, status: 400))

      2.times { subscription.charge! && nil }
      expect(subscription.reload).to have_attributes(status: "past_due", failed_attempts: 2)
      expect(subscription.next_charge_at).to be_within(1.minute).of(1.day.from_now)
      expect(events).to include("subscription_past_due.przelewy24")

      subscription.charge!
      expect(subscription.reload).to have_attributes(status: "canceled", cancel_reason: /declined/)
    end

    it "resets the failure counter after a successful renewal" do
      subscription.update!(status: "past_due", failed_attempts: 2)
      stub_alias_charge
      payment = subscription.charge!
      settle(payment, order_id: 999)
      expect(subscription.reload).to have_attributes(status: "active", failed_attempts: 0)
    end

    it "counts an expired charge as a failure" do
      subscription
      stub_alias_charge
      payment = subscription.charge!
      payment.update_columns(created_at: 3.days.ago)

      expect(Przelewy24Payment::Payment.expire_stale!).to eq(1)
      expect(subscription.reload).to have_attributes(status: "past_due", failed_attempts: 1)
    end

    it "charges only due subscriptions and never canceled ones" do
      due = subscription
      due.update!(next_charge_at: 1.hour.ago)
      other = start.tap { |s| settle(s.first_payment, order_id: 123) }.reload
      other.update!(next_charge_at: 1.week.from_now)
      stub_alias_charge

      expect(described_class.charge_due!).to eq(1)
      due.przelewy24_payments.pending.destroy_all
      due.cancel!
      expect(described_class.charge_due!).to eq(0)
    end

    it "stops charging after cancel!" do
      subscription
      expect(subscription.cancel!(reason: "customer_request")).to be true
      expect(subscription.cancel!).to be false
      expect(subscription).to have_attributes(status: "canceled", cancel_reason: "customer_request", next_charge_at: nil)
      expect(subscription.charge!).to be_nil
      expect(events).to include("subscription_canceled.przelewy24")
    end

    it "runs from the job" do
      subscription.update!(next_charge_at: 1.hour.ago)
      stub_alias_charge
      expect { Przelewy24Payment::ChargeDueSubscriptionsJob.perform_now }.to change { subscription.przelewy24_payments.count }.by(1)
    end
  end
end
