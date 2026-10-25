# przelewy24_payment

Rails engine for [Przelewy24](https://www.przelewy24.pl) (REST API v1): transaction registration, signed webhook handling with automatic verification, refunds, payment methods, an install generator and test helpers.

Requires Rails 7.1+ and Ruby 3.2+.

## Installation

Add the gem to your `Gemfile` and run the install generator:

```bash
bundle add przelewy24_payment
bin/rails generate przelewy24_payment:install
bin/rails db:migrate
```

### What the generator does

`rails generate przelewy24_payment:install` (alias: `rails g przelewy24_payment:install`) performs four steps:

| Step | Result |
| --- | --- |
| Initializer | `config/initializers/przelewy24_payment.rb` with all settings and callbacks |
| Migrations | `create_przelewy24_payments`, `create_przelewy24_refunds` and `create_przelewy24_subscriptions` in `db/migrate` |
| Route | `mount Przelewy24Payment::Engine => "/przelewy24"` in `config/routes.rb` |
| Next steps | a short checklist printed to the terminal |

Options:

| Option | Default | Purpose |
| --- | --- | --- |
| `--mount-path=/payments/p24` | `/przelewy24` | where the webhook engine is mounted; the `urlStatus` sent to Przelewy24 follows it automatically |
| `--skip-subscriptions` | off | do not generate the subscriptions migration if you only need one-off payments |

The command is safe to re-run: the route is added only once and existing files prompt before being overwritten (use `--force` to overwrite, `--skip` to keep yours). Use `rails destroy przelewy24_payment:install` to remove the generated files and the route.

Then:

1. Add your credentials (see below).
2. Include `Przelewy24Payment::Payable` in the model that gets paid (e.g. `Order`).
3. Make your app reachable by Przelewy24: set `config.url_options` to your public host. In development use a tunnel (ngrok, cloudflared) because Przelewy24 must be able to reach `POST /przelewy24/webhooks/status`.

The engine works with any model: the payment is linked polymorphically, so no columns are added to your own tables.

## Configuration

All settings live in `config/initializers/przelewy24_payment.rb`. Values passed there win over ENV.

### Customizing

**Mount path.** Use `rails g przelewy24_payment:install --mount-path=/payments/p24`, or change the `mount` line in `config/routes.rb` yourself.

**Webhook controller.** Set `config.parent_controller = "ApplicationController"` (or any controller of yours) to reuse your logging, error reporting or `rescue_from` handlers. CSRF protection is skipped automatically. Do not inherit from a controller that requires a signed-in user: Przelewy24 calls the endpoints without a session.

**Models.** The models live under `Przelewy24Payment::` with `przelewy24_*` tables, so they never clash with your own `Payment` or `Order`. Extend them with load hooks instead of forking:

```ruby
# config/initializers/przelewy24_payment.rb
ActiveSupport.on_load(:przelewy24_payment_payment) do   # also :przelewy24_payment_refund, :przelewy24_payment_subscription
  scope :recent, -> { where(created_at: 1.week.ago..) }
  after_commit :track_in_analytics, on: :update

  def track_in_analytics = Analytics.track("p24_#{status}", id: id)
end
```

The payable side is yours entirely: any model can `include Przelewy24Payment::Payable`, whatever its name or table.

### Credentials

Rails credentials (`bin/rails credentials:edit`) are read first by the generated initializer:

```yaml
przelewy24:
  merchant_id: 12345
  pos_id: 12345      # optional, defaults to merchant_id
  api_key: "..."     # REST API key ("klucz do raportów") from the Przelewy24 panel
  crc_key: "..."     # CRC key of the shop
```

ENV variables are the fallback, and are also read directly if the initializer does not set the value:

| Variable | Required | Purpose |
| --- | --- | --- |
| `PRZELEWY24_MERCHANT_ID` | yes | merchant id |
| `PRZELEWY24_POS_ID` | no | shop id, defaults to the merchant id |
| `PRZELEWY24_API_KEY` | yes | REST API key (HTTP basic auth password) |
| `PRZELEWY24_CRC_KEY` | yes | key used to sign requests and verify webhooks |
| `PRZELEWY24_ENVIRONMENT` | no | `sandbox` (default) or `production` |

Missing credentials raise `Przelewy24Payment::ConfigurationError` on the first API call (not at boot), naming every missing key. Sandbox and production use different credentials, so keep them per environment.

### Options

| Option | Default | Purpose |
| --- | --- | --- |
| `environment` | `:sandbox` | `:sandbox` or `:production` |
| `default_country` / `default_language` | `"PL"` / `"pl"` | sent on registration |
| `url_options` | `{}` | host and protocol used to build the status webhook URL, e.g. `{ host: "shop.example.com", protocol: "https" }` |
| `allowed_ips` | `nil` | restrict webhooks to these IPs or CIDR ranges (Przelewy24 publishes them in its docs) |
| `open_timeout` / `timeout` | `5` / `15` | seconds |
| `logger` | `Rails.logger` | |
| `on_payment_verified`, `on_payment_failed`, `on_refund` | `nil` | callbacks, see [Webhooks](#webhooks) |
| `parent_controller` | `"ActionController::API"` | class the webhook controller inherits from, see below |
| `max_failed_attempts` | `3` | failed subscription charges before it is canceled |
| `retry_interval` | `1.day` | wait before retrying a failed subscription charge |

## Usage

```ruby
class Order < ApplicationRecord
  include Przelewy24Payment::Payable   # has_many :przelewy24_payments

  def payment_verified! = update!(status: :paid)
  def payment_failed!   = update!(status: :payment_failed)
end

# Controller: every attempt creates a new payment with a fresh session id.
payment = Przelewy24Payment::Payment.start!(
  payable: order, amount: order.price, currency: order.currency,
  email: current_user.email, description: "Order #{order.id}",
  return_url: order_url(order)
)
redirect_to payment.redirect_url, allow_other_host: true
```

Amounts are decimals in major units (`BigDecimal`, `String` or `Integer`); the gem converts to grosze.

### Webhooks

The engine ships the webhook endpoints, so your app needs no controller or route of its own. After `rails g przelewy24_payment:install` the engine is mounted at `/przelewy24` and exposes:

| Endpoint | Purpose |
| --- | --- |
| `POST /przelewy24/webhooks/status` | transaction status notification |
| `POST /przelewy24/webhooks/refund` | refund status notification |

The status URL is sent to Przelewy24 automatically as `urlStatus` when you call `Payment.start!`. It is built from `config.url_options`, so in development point that at a tunnel (ngrok, cloudflared). You do not need to enter anything in the Przelewy24 panel.

#### What happens when a notification arrives

1. The JSON body is parsed and its `sign` (SHA-384) and `merchantId` are verified. Optionally the request IP is checked against `allowed_ips`.
2. The `Payment` row is looked up by `sessionId` and locked.
3. The transaction is confirmed with `PUT /transaction/verify`, which Przelewy24 requires for settlement. The payment becomes `verified` or `failed`. This happens only once per payment, so repeated notifications never trigger a second verification.
4. Your callback runs (`on_payment_verified` or `on_payment_failed`), and the payment is stamped with `notified_at` in the same database transaction.

#### Hooking into webhooks from your app

Set callbacks in `config/initializers/przelewy24_payment.rb`. They receive the `Przelewy24Payment::Payment`; `payment.payable` is your model (e.g. the `Order`).

```ruby
Przelewy24Payment.configure do |config|
  config.on_payment_verified = ->(payment) { payment.payable.mark_as_paid! }
  config.on_payment_failed   = ->(payment) { payment.payable.mark_as_failed! }
  config.on_refund           = ->(refund)  { RefundMailer.completed(refund).deliver_later }
end
```

For side effects that should not live in the configuration (metrics, mails, auditing), subscribe to the instrumentation events instead, see [Instrumentation](#instrumentation).

#### Delivery guarantee: at least once

The callback and the `notified_at` stamp share one transaction. If the callback raises:

- the transaction is rolled back, including any database changes the callback made;
- the endpoint answers `500`, so Przelewy24 retries the notification;
- the retry does not verify the transaction again, it only runs the callback again.

A paid order can therefore never be left un-notified because of a transient error in your code. The flip side is that a callback may run more than once, so keep side effects outside the database (emails, HTTP calls, enqueued jobs) idempotent. `payment.notified_at` tells you whether the callback has completed.

#### Responses

| Status | Meaning |
| --- | --- |
| `200` | processed (also returned for duplicate notifications) |
| `400` | malformed or incomplete payload |
| `401` | invalid signature |
| `403` | IP not in `allowed_ips` |
| `404` | unknown `sessionId` |
| `500` | Przelewy24 API unavailable or your callback raised; Przelewy24 will retry |

### Failed, abandoned and retried payments

Every payment attempt is its own `Przelewy24Payment::Payment` with a fresh `session_id`, so retrying is simply starting a new payment for the same record. A payment is in one of these states:

| Status | Meaning |
| --- | --- |
| `pending` | registered, waiting for the customer or for the notification |
| `verified` | confirmed by Przelewy24, money received |
| `failed` | Przelewy24 rejected the verification |
| `expired` | abandoned attempt closed by `Payment.expire_stale!` |

**The customer cancels or closes the gateway.** Przelewy24 sends no notification in this case, the customer just comes back to your `return_url`. The payment stays `pending`. Do not mark anything as paid or failed on the return page; show the current state and offer a retry:

```ruby
class OrdersController < ApplicationController
  def pay
    order = current_user.orders.find(params[:id])
    return redirect_to(order, notice: "Already paid.") if order.przelewy24_paid?

    payment = Przelewy24Payment::Payment.start!(
      payable: order, amount: order.price, currency: order.currency,
      email: current_user.email, description: "Order #{order.id}", return_url: order_url(order)
    )
    redirect_to payment.redirect_url, allow_other_host: true
  rescue Przelewy24Payment::AlreadyPaidError
    redirect_to order, notice: "Already paid."
  rescue Przelewy24Payment::Error => e
    redirect_to order, alert: "Payment could not be started: #{e.message}"
  end

  def show
    @order = current_user.orders.find(params[:id])
    @payment = @order.latest_przelewy24_payment   # pending / verified / failed
  end
end
```

Call `pay` again to retry: it creates a new attempt. Show a "Pay again" button whenever the order is not paid.

**Double-payment protection.** `Payment.start!` raises `Przelewy24Payment::AlreadyPaidError` when the payable already has a verified payment, so a retry can never charge the customer twice. An older attempt can still be paid late (for example from a tab that stayed open); its notification is processed normally. Make `on_payment_verified` idempotent for that case, and refund the extra payment if it happens:

```ruby
config.on_payment_verified = lambda do |payment|
  order = payment.payable
  order.paid? ? Rails.logger.warn("Duplicate payment #{payment.id}") : order.payment_verified!
end
```

**Verification rejected.** If Przelewy24 rejects the verification, the payment becomes `failed` and `on_payment_failed` runs. The customer can retry the same way.

**Registration errors.** If Przelewy24 refuses the registration or is unreachable, `Payment.start!` raises (`ValidationError`, `AuthenticationError`, `ConnectionError`, ...) and the attempt is marked `failed`. Nothing is left pending.

**Cleaning up abandoned attempts.** Run `Payment.expire_stale!` from a recurring job (cron, Solid Queue, GoodJob) to close attempts that never got a notification. Expired payments are still settled if a late notification arrives.

```ruby
class ExpirePrzelewy24PaymentsJob < ApplicationJob
  def perform = Przelewy24Payment::Payment.expire_stale!(older_than: 1.day)
end
```

### BLIK on your own page

Instead of redirecting to the Przelewy24 gateway, the customer can type the 6-digit BLIK code in your checkout. Register the transaction with the customer's `PSU` (IP and user agent, required by Przelewy24), then charge it:

```ruby
payment = Przelewy24Payment::Payment.start!(
  payable: order, amount: order.price, currency: "PLN", email: user.email,
  description: "Order #{order.id}", return_url: order_url(order),
  additional: { PSU: { IP: request.remote_ip, userAgent: request.user_agent } }
)
payment.charge_blik_code!(blik_code: params[:blik_code])
# The result still arrives through the status webhook; show "confirm in your banking app".
```

Save an alias for later 1-click payments by passing `alias_value:` and `alias_label:` (5-35 characters) to `charge_blik_code!`. Later payments by that alias need no code:

```ruby
client = Przelewy24Payment.client
client.blik.aliases(user.email)                       # stored aliases (up to ~60 s after a payment)

payment = Przelewy24Payment::Payment.start!(..., method_ref_id: alias_value, additional: { PSU: psu })
payment.charge_blik_alias!(alias_value: alias_value)
```

If the alias is linked to several bank apps, Przelewy24 answers `409` and the gem raises `Przelewy24Payment::AmbiguousAliasError`; let the customer pick one of `error.alternative_keys` and call `client.blik.charge_by_alternative_key(token:, alternative_key:)`. An expired alias (error 68) needs a new code payment.

Sandbox: use the code `777XXX` for a successful BLIK payment and any other six digits to simulate a failure.

### Cards (one-click and recurring)

Card references are not stored by the gem. After a paid card transaction fetch the reference and keep it for later charges:

```ruby
ref = Przelewy24Payment.client.cards.reference_for(payment.p24_order_id)   # GET card/info/{orderId}

payment = Przelewy24Payment::Payment.start!(..., method_ref_id: ref)
payment.charge_card!                       # off-session, no customer present
payment.charge_card!(three_ds: true)       # => { order_id:, redirect_url: } redirect the customer when present
```

References from Google Pay, Apple Pay or VISA Mobile cannot be used for recurring charges. Card one-click and recurring features must be enabled for your account by Przelewy24.

### Subscriptions

Przelewy24 has **no subscription object and no cancel endpoint**. It only lets you charge a stored BLIK alias or card reference without the customer present. `Przelewy24Payment::Subscription` keeps the schedule on your side and drives those charges:

| Status | Meaning |
| --- | --- |
| `pending` | first payment not confirmed yet |
| `active` | charged every `frequency` while payments succeed |
| `past_due` | the last charge failed; retried after `retry_interval` |
| `canceled` | no more charges (by you, by the customer, or after `max_failed_attempts`) |

**1. Start (customer present).** `frequency` uses Przelewy24 notation: a number and `D`, `W`, `M` or `Y` (`"1M"`, `"7D"`).

```ruby
subscription = Przelewy24Payment::Subscription.start!(
  owner: current_user, payment_method: :card,          # or :blik
  amount: BigDecimal("29.00"), currency: "PLN", email: current_user.email,
  description: "Pro plan", frequency: "1M", return_url: account_url,
  psu: { IP: request.remote_ip, userAgent: request.user_agent }
)
redirect_to subscription.first_payment.redirect_url, allow_other_host: true
```

For BLIK pass `recurring:` exactly as described in the Przelewy24 docs (type `O`, `M` or `A`, frequency, limits), then complete the first payment with `subscription.first_payment.charge_blik_code!(blik_code: params[:code])`. The alias and `recurring` stored on the subscription are used automatically. BLIK recurring payments are **not enabled by default**; ask Przelewy24 support to switch them on.

**2. Activation.** When the first payment is verified by the status webhook, the subscription becomes `active`; the card reference (via `card/info`) or the BLIK alias is stored and `next_charge_at` is set.

**3. Renewals.** Schedule the job (hourly is fine) with cron, Solid Queue recurring tasks or GoodJob cron:

```ruby
Przelewy24Payment::ChargeDueSubscriptionsJob.perform_later   # charges due subscriptions and closes stale attempts
# or: Przelewy24Payment::Subscription.charge_due!
```

Each charge creates a normal `Payment` (its `payable` is the subscription), registers it with the stored method and waits for the status webhook, which renews the subscription. A charge already in flight is never duplicated.

**4. Failures.** A rejected, failed or expired charge moves the subscription to `past_due` and retries after `retry_interval`. After `max_failed_attempts` consecutive failures it is canceled with the last error as `cancel_reason`. A failed first payment cancels the pending subscription.

**5. Cancel.** `subscription.cancel!(reason: "customer_request")` stops all future charges. Przelewy24 is not contacted (there is nothing to cancel there). If the customer revokes consent in their bank app, the next charge fails and the retry rules above apply.

React to lifecycle changes with instrumentation events (`subscription_activated`, `subscription_renewed`, `subscription_past_due`, `subscription_canceled`):

```ruby
ActiveSupport::Notifications.subscribe("subscription_renewed.przelewy24") do |*, payload|
  payload[:subscription].owner.extend_access!   # payload[:payment] is the paid renewal
end
```

Payment callbacks (`on_payment_verified`) also fire for subscription payments; there `payment.payable` is the `Subscription` and `payment.subscription.owner` is your record. Not supported: the BLIK alias update notification (its payload is not documented by Przelewy24); read aliases with `client.blik.aliases`.

### Refunds

```ruby
Przelewy24Payment::Refund.request!(payment: payment, amount: BigDecimal("5.00"))
```

Refund status notifications arrive at `/przelewy24/webhooks/refund` and update `Refund#status`.

### Low-level client

```ruby
client = Przelewy24Payment.client
client.test_access
client.payment_methods.list(lang: "pl")
client.transactions.find_by_session_id("ABC")
```

### Instrumentation

`ActiveSupport::Notifications` events: `request.przelewy24`, `payment_verified.przelewy24`, `payment_failed.przelewy24`, `refund_completed.przelewy24`, `refund_failed.przelewy24`, `subscription_activated.przelewy24`, `subscription_renewed.przelewy24`, `subscription_past_due.przelewy24`, `subscription_canceled.przelewy24`. Secrets (`sign`, `crc_key`, `api_key`) are added to `filter_parameters`.

`payment_verified` and `payment_failed` are published right after the callback succeeds (payload: `payment:`), `refund_*` events carry `refund:`.

```ruby
ActiveSupport::Notifications.subscribe("payment_verified.przelewy24") do |*, payload|
  Rails.logger.info("Paid: #{payload[:payment].session_id}")
end
```

### Testing in your app

```ruby
payload = Przelewy24Payment::TestHelpers.status_payload(payment)
post "/przelewy24/webhooks/status", params: payload, as: :json
```

In development expose the app with a tunnel (ngrok, cloudflared) and set `url_options` to its host.

## Upgrading from 0.x / 1.x

2.0 is a full rewrite and not compatible with earlier versions. Remove the old configuration, run the install generator and migrate order-specific payment columns (`session_id`, `external_id`) to `Przelewy24Payment::Payment`.

## Development

```bash
bundle install
bundle exec rake        # specs
bundle exec rubocop
```

MIT licensed.
