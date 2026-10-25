# frozen_string_literal: true

require "simplecov"
SimpleCov.start { add_filter "/spec/" }

ENV["RAILS_ENV"] = "test"
require_relative "dummy/config/application"
Rails.application.initialize!

require "rspec/rails"
require "webmock/rspec"
require "przelewy24_payment/test_helpers"

ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :orders, force: true do |t|
    t.timestamps
  end

  create_table :przelewy24_payments, force: true do |t|
    t.references :payable, polymorphic: true, null: false
    t.string :session_id, null: false
    t.string :token
    t.integer :amount, null: false
    t.string :currency, null: false
    t.string :status, null: false, default: "pending"
    t.bigint :p24_order_id
    t.integer :method_id
    t.json :payload
    t.datetime :verified_at
    t.datetime :notified_at
    t.timestamps
  end
  add_index :przelewy24_payments, :session_id, unique: true

  create_table :przelewy24_subscriptions, force: true do |t|
    t.references :owner, polymorphic: true, null: false
    t.string :payment_method, null: false
    t.string :status, null: false, default: "pending"
    t.string :frequency, null: false
    t.integer :amount, null: false
    t.string :currency, null: false
    t.string :email, null: false
    t.string :description
    t.string :return_url, null: false
    t.string :alias_value
    t.string :alias_label
    t.string :method_ref
    t.json :recurring
    t.json :psu
    t.integer :failed_attempts, null: false, default: 0
    t.datetime :next_charge_at
    t.datetime :last_charged_at
    t.datetime :canceled_at
    t.string :cancel_reason
    t.timestamps
  end

  create_table :przelewy24_refunds, force: true do |t|
    t.references :payment, null: false
    t.integer :amount, null: false
    t.string :request_id, null: false
    t.string :refunds_uuid, null: false
    t.string :status, null: false, default: "pending"
    t.timestamps
  end
  add_index :przelewy24_refunds, :refunds_uuid, unique: true
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.before do
    Przelewy24Payment.reset_configuration!
    Przelewy24Payment.configure do |c|
      c.environment = :sandbox
      c.merchant_id = 12_345
      c.api_key = "api-key"
      c.crc_key = "crc-key"
      c.url_options = { host: "shop.test", protocol: "https" }
    end
  end
end
