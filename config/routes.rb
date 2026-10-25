# frozen_string_literal: true

Przelewy24Payment::Engine.routes.draw do
  post "webhooks/status", to: "webhooks#status", as: :status_webhooks
  post "webhooks/refund", to: "webhooks#refund", as: :refund_webhooks
end
