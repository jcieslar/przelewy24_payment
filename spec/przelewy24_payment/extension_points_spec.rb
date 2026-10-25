# frozen_string_literal: true

require "spec_helper"

RSpec.describe "extension points" do
  it "inherits webhooks from ActionController::API by default" do
    expect(Przelewy24Payment::WebhooksController.superclass).to eq(ActionController::API)
    expect(Przelewy24Payment.configuration.parent_controller).to eq("ActionController::API")
  end

  it "runs load hooks so host apps can extend the models" do
    ActiveSupport.on_load(:przelewy24_payment_payment) do
      def self.extension_marker = :payment
    end
    ActiveSupport.on_load(:przelewy24_payment_refund) do
      def self.extension_marker = :refund
    end
    ActiveSupport.on_load(:przelewy24_payment_subscription) do
      def self.extension_marker = :subscription
    end

    expect([ Przelewy24Payment::Payment, Przelewy24Payment::Refund, Przelewy24Payment::Subscription ].map(&:extension_marker))
      .to eq(%i[payment refund subscription])
  end

  it "builds the status webhook url from the engine mount point" do
    url = Przelewy24Payment::Engine.routes.url_helpers.status_webhooks_url(host: "shop.test", protocol: "https")
    expect(url).to eq("https://shop.test/przelewy24/webhooks/status")
  end
end
