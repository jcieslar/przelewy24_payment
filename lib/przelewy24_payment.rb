require "przelewy24_payment/version"
require "przelewy24_payment/engine"

module Przelewy24Payment

  module Controllers
    autoload :Przelewy24Payment, 'controllers/przelewy24_payment'
  end

  mattr_accessor :seller_id
  @@seller_id = '17329'

  mattr_accessor :language
  @@language = 'pl'

  mattr_accessor :mode
  @@mode = :development

  mattr_accessor :error_url
  @@error_url = ''

  mattr_accessor :comeback_url
  @@comeback_url = ''

  mattr_accessor :crc_key
  @@crc_key = ''

  def self.setup
    yield self
  end

  def self.complete_url(params)
    params
  end

  def self.post_url
    if @@mode == :development
      'https://sandbox.przelewy24.pl/index.php'
    elsif @@mode == :production
      'https://secure.przelewy24.pl/index.php'
    end
  end

  def self.transaction_url
    if @@mode == :development
      'https://sandbox.przelewy24.pl/transakcja.php'
    elsif @mode == :production
      'https://secure.przelewy24.pl/index.php'
    end
  end

  def self.p24_price(price)
    price.present? ? (price.to_f.round(2) * 100) : 0
  end

  def self.friendly_token
    SecureRandom.base64(15).tr('+/=lIO0', 'aqrsxyz')
  end

  def self.calculate_crc(value,session_id, crc_key=nil)
    calc_md5 = Digest::MD5.hexdigest(session_id.to_s + "|" + (seller_id).to_s + "|" + (p24_price(value)).to_s + "|" + (crc_key.nil? ? "" : crc_key.to_s))
    return calc_md5
  end

end
