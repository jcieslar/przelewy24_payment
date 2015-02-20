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
    allowed_ips.include?(ip)
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

  def self.calculate_sign(session,merchant,amount,currency)
    Digest::MD5.hexdigest(session.to_s + "|" + merchant.to_s + "|" + amount.to_s + "|" + currency.to_s + "|" + crc_key.to_s)
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

    data[:p24_sign] = calculate_sign(data[:session_id],data[:merchant_id],data[:p24_amount],data[:currency])

    data
  end

  def self.test_connection_params(data={})
    data[:p24_merchant_id] ||=  merchant_id
    data[:p24_pos_id] ||= pos_id
    data[:p24_sign] = Digest::MD5.hexdigest(data[:p24_pos_id].to_s + "|" + crc_key.to_s)
    data
  end

end
