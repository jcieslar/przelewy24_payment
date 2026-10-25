# Changelog

## 2.0.0

Complete rewrite as a Rails engine.

- REST API v1 client (Faraday): `testAccess`, register, verify, by-session lookup, refunds, payment methods.
- `Payment` / `Refund` models, `Payable` concern, idempotent signed webhooks.
- Install generator, credentials/ENV configuration, ActiveSupport::Notifications events.
- BLIK (code, 1-click, aliases), card reference charges, `Subscription` model with scheduled charges, retries and cancellation.
- TLS verification always on; money handled as integer minor units.
