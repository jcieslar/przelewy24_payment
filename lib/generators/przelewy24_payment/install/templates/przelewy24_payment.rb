Przelewy24Payment.setup do |config|
  config.seller_id = 'your_seller_id'
  config.language = 'pl'
  config.mode = :development
  config.error_url = '/your_controller/comeback'
  config.comeback_url = '/your_controller/comeback'
  config.hostname = {
      :development => "http://localhost:3000",
      :production => "your.domain",
      :staging => "staging.domain"
  }
end
