module Przelewy24Payment::PaymentHelper
  def payment_button(date)
    render :partial => 'przelewy24_payment/payment_form', :locals => { :data => date }
  end
end
