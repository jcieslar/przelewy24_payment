module Przelewy24PaymentController

  def self.included(base)
    base.class_eval do
      include InstanceMethods
      extend ClassMethods
    end
  end

  module ClassMethods

  end # ClassMethods

  module InstanceMethods
    def payment_success(payment_params)
    end

    def payment_error(payment_params, code, description)
    end

    def payment_verify(response_params)
      return data = { :amount => 100.0, :crc_key => Przelewy24Payment.crc_key }
    end

    def comeback
      result = przelewy24_verify(params,request.remote_ip)
      if result.error == "0"
        payment_success(params)
      else
        payment_error(params, result.error, result.errorMessage)
      end
    end

    private

    def przelewy24_verify(params,ip)
      return '' unless Przelewy24Payment.check_ip(ip)
      require 'net/https'
      require 'net/http'
      require 'open-uri'
      require 'openssl'

      data = payment_verify(params)
      params_new = {
        :p24_merchant_id => params[:p24_merchant_id],
        :p24_pos_id => params[:p24_pos_id],
        :p24_session_id => params[:p24_session_id],
        :p24_amount => Przelewy24Payment.make_p24_amount(data[:amount]),
        :p24_currency => params[:p24_currency],
        :p24_order_id => params[:p24_order_id]
      }
      params_new[:p24_sign] = Przelewy24Payment.verify_sign(data,params_new)

      url = URI.parse(Przelewy24Payment.verification_request_url)
      req = Net::HTTP::Post.new(url.path,{"User-Agent" => "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.10) Gecko/20100915 Ubuntu/10.04 (lucid) Firefox/3.6.10"})
      req.form_data = params_new
      con = Net::HTTP.new(url.host, 443)
      con.use_ssl = true
      con.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = con.start {|http| http.request(req)}
      return  Przelewy24Payment.parse_response response.body
    end

  end # InstanceMethods


end
