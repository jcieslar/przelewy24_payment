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
      return data = { :amount => 100.0, :crc_key => '' }
    end

    def comeback
      @response = przelewy24_verify(params)
      result = @response.split("\r\n")
      if result[1] == "TRUE"
        payment_success(params)
      else
        payment_error(params, :error_code => result[2], :error_descr => result[3])
      end
    end

    private

    def przelewy24_verify(params)
      require 'net/https'
      require 'net/http'
      require 'open-uri'
      require 'openssl'

      data = payment_verify(params)
      params_new = {:p24_session_id => params[:p24_session_id], :p24_order_id => params[:p24_order_id], :p24_id_sprzedawcy => Przelewy24Payment.seller_id, :p24_kwota => Przelewy24Payment.p24_price(data[:amount]).to_s}
      if data[:crc_key].present?
        params_new[:p24_crc] = Digest::MD5.hexdigest(params[:p24_session_id]+"|"+params[:p24_order_id]+"|"+params[:p24_kwota]+"|"+data[:crc_key])
      end

      url = URI.parse(Przelewy24Payment.transaction_url)
      req = Net::HTTP::Post.new(url.path,{"User-Agent" => "Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.2.10) Gecko/20100915 Ubuntu/10.04 (lucid) Firefox/3.6.10"})
      req.form_data = params_new
      con = Net::HTTP.new(url.host, 443)
      con.use_ssl = true
      con.verify_mode = OpenSSL::SSL::VERIFY_NONE
      response = con.start {|http| http.request(req)}
      return response.body
    end

  end # InstanceMethods


end
