# frozen_string_literal: true

module Przelewy24Payment
  # Inherits from config.parent_controller (default ActionController::API).
  # Do not point it at a controller that requires a signed-in user: Przelewy24
  # calls these endpoints without a session.
  class WebhooksController < Przelewy24Payment.configuration.parent_controller.constantize
    skip_forgery_protection if respond_to?(:skip_forgery_protection)

    before_action :restrict_ip

    # POST /przelewy24/webhooks/status
    def status
      notification = Notification.new(webhook_params).verify!
      payment = Payment.find_by!(session_id: notification.session_id)

      payment.settle!(notification)
      payment.deliver_callbacks!
      head :ok
    rescue InvalidNotificationError
      head :bad_request
    rescue SignatureError
      head :unauthorized
    rescue ActiveRecord::RecordNotFound
      head :not_found
    rescue StandardError => e
      # Includes errors raised by user callbacks: answer 5xx so Przelewy24 retries.
      Przelewy24Payment.configuration.logger&.error("[Przelewy24] webhook failed: #{e.class}: #{e.message}")
      head :internal_server_error
    end

    # POST /przelewy24/webhooks/refund
    def refund
      notification = RefundNotification.new(webhook_params).verify!
      refund = Refund.find_by!(refunds_uuid: notification.refunds_uuid)

      refund.update!(status: notification.success? ? "completed" : "failed")
      Instrumentation.instrument("refund_#{refund.status}", refund: refund)
      Przelewy24Payment.configuration.on_refund&.call(refund)
      head :ok
    rescue InvalidNotificationError
      head :bad_request
    rescue SignatureError
      head :unauthorized
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    private

    # Raw JSON body is the source of truth; Rails-added keys are dropped.
    def webhook_params
      request.request_parameters.except("controller", "action", "webhook")
    end

    def restrict_ip
      allowed = Przelewy24Payment.configuration.allowed_ips
      return if allowed.blank? || allowed.any? { |range| IPAddr.new(range).include?(request.remote_ip) }

      head :forbidden
    end
  end
end
