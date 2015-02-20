Przelewy24Payment.setup do |config|
  config.merchant_id = 'your_merchant_id'
  config.pos_id = 'your_shop_id_default_merchant_id'
  config.crc_key = 'crc_key'
  config.language = 'pl'
  config.currency = 'PLN'
  config.country = 'PL'
  config.mode = :development
  config.url_status = '/your_controller/comeback'
  config.url_return = '/your_controller/comeback'
  config.hostname = {
      :development => "http://127.0.0.1:3000",
      :production => "your.domain",
      :staging => "staging.domain"
  }
end
