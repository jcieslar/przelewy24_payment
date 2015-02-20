module Przelewy24Payment::PaymentHelper
  def payment_button(data)
    render :partial => 'przelewy24_payment/payment_form', :locals => { :data => Przelewy24Payment.prepare_form(data)}
  end
end
