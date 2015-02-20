require "przelewy24_payment/version"
require "przelewy24_payment/engine"
require "przelewy24_payment/przelewy24_payment_controller"

module Przelewy24Payment

  mattr_accessor :merchant_id
  @@merchant_id = ''

  mattr_accessor :pos_id
  @@pos_id = ''

  mattr_accessor :language
  @@language = 'pl'

  mattr_accessor :currency
  @@language = 'PLN'

  mattr_accessor :mode
  @@mode = :development

  mattr_accessor :url_status
  @@url_status = ''

  mattr_accessor :url_return
  @@url_return = ''

  mattr_accessor :api_version
  @@api_version = '3.2'

  mattr_accessor :crc_key
  @@crc_key = ''

  mattr_accessor :allowed_ips
  @@allowed_ips = %w(91.216.191.181 91.216.191.182 91.216.191.183 91.216.191.184 91.216.191.185)

  mattr_accessor :allowed_languages
  @@allowed_languages = %w(pl en de es it)

  mattr_accessor :country
  @@country = 'PL'

  mattr_accessor :allowed_countries
  @@allowed_countries = %w(AD AT BE CY CZ DK EE FI FR EL ES NO PL PT SM SK SI CH SE HU GB IT NL IE IS LT LV LU MT US CA JP UA BY RY RU)

  mattr_accessor :hostname
  @@hostname = { :development => "http://127.0.0.1:3000" }

  def self.setup
    yield self
  end

  def self.check_ip(ip)
    if @@mode == :production
      allowed_ips.include?(ip)
    else
      true
    end
  end

  def self.complete_url(params)
    params
  end

  def self.test_connection_url
    if @@mode == :production
      'https://secure.przelewy24.pl/testConnection'
    else
      'https://sandbox.przelewy24.pl/testConnection'
    end
  end

  def self.transaction_request_url
    if @@mode == :production
      'https://secure.przelewy24.pl/trnDirect'
    else
      'https://sandbox.przelewy24.pl/trnDirect'
    end
  end

  def self.verification_request_url
    if @@mode == :production
      'https://secure.przelewy24.pl/trnVerify'
    else
      'https://sandbox.przelewy24.pl/trnVerify'
    end
  end

  def self.friendly_token
    SecureRandom.base64(15).tr('+/=lIO0', 'aqrsxyz')
  end

  def self.calculate_sign(session,merchant,amount,currency,crc)
    Digest::MD5.hexdigest(session.to_s + "|" + merchant.to_s + "|" + amount.to_s + "|" + currency.to_s + "|" + crc.to_s)
  end

  def self.get_hostname
    @@hostname[@@mode]
  end

  def self.get_url_status
    get_hostname + @@url_status
  end

  def self.get_url_return
    get_hostname + @@url_return
  end

  def self.make_p24_amount(price)
    price.present? ? (price.to_f.round(2) * 100).to_i : 0
  end

  def self.make_p24_language(data_language)
    lang = (data_language || language)
    if allowed_languages.include?(lang)
      lang
    else
      'pl'
    end
  end

  def self.make_p24_country(data_country)
    country_code = (data_country || country)
    if allowed_countries.include?(country_code)
      country_code
    else
      'PL'
    end
  end

  def self.make_p24_currency(data_currency)
    (data_currency || currency).upcase
  end

  def self.prepare_form(data)
    #prepare mandatory fields
    data[:merchant_id] ||=  merchant_id
    data[:pos_id] ||= pos_id
    data[:api_version] ||= api_version
    data[:p24_amount] = make_p24_amount(data[:amount])
    data[:currency] =  make_p24_currency (data[:currency])
    data[:language] = make_p24_language(data[:language]) if data[:language]
    data[:country] = make_p24_country(data[:country])
    data[:url_return] ||= get_url_return
    data[:url_status] ||= get_url_status
    data[:crc_key] ||= crc_key
    data[:encoding] ||= 'UTF-8'
    data[:p24_sign] = calculate_sign(data[:session_id],data[:merchant_id],data[:p24_amount],data[:currency], data[:crc_key])
    data
  end

  def self.test_connection_params(data={})
    data[:p24_merchant_id] ||=  merchant_id
    data[:p24_pos_id] ||= pos_id
    data[:p24_sign] = Digest::MD5.hexdigest(data[:p24_pos_id].to_s + "|" + crc_key.to_s)
    data
  end

  def self.verify_sign(data,params_new)
    Digest::MD5.hexdigest(params_new[:p24_session_id].to_s+"|"+params_new[:p24_order_id].to_s+"|"+make_p24_amount(data[:amount]).to_s+"|"+params_new[:p24_currency].to_s+"|"+data[:crc_key].to_s)
  end

  def self.parse_response(response)
    ret = OpenStruct.new
    response.split("&").each do |arg|
      line = arg.split('=')
      ret[line[0].strip] = line[1].force_encoding("ISO-8859-2").encode!("UTF-8")
    end
    ret
  end

  ## P24 Error codes
  # err00: Incorrect call
  # err01: Authorization answer confirmation was not received.
  # err02: Authorization answer was not received.
  # err03: This query has been already processed.
  # err04: Authorization query incomplete or incorrect.
  # err05: Store configuration cannot be read.
  # err06: Saving of authorization query failed.
  # err07: Another payment is being concluded.
  # err08: Undetermined store connection status.
  # err09: Permitted corrections amount has been exceeded.
  # err10: Incorrect transaction value!
  # err49: To high transaction risk factor.
  # err51: Incorrect reference method.
  # err52: Incorrect feedback on session information!
  # err53: Transaction error !: err54: Incorrect transaction value!
  # err55: Incorrect transaction id!
  # err56: Incorrect card
  # err57: Incompatibility of TEST flag
  # err58: Incorrect sequence number !
  # err101: Incorrect call
  # err102: Allowed transaction time has expired
  # err103: Incorrect transfer value.
  # err104: Transaction awaits confirmation.
  # err105: Transaction finished after allowed time.
  # err106: Transaction result verification error
  # err161: Transaction request terminated by user
  # err162: Transaction request terminated by user
end
