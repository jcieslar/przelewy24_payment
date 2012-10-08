Przelewy24Payment.setup do |config|
  config.seller_id = 'your_seller_id'
  config.language = 'pl'
  config.mode = :development
  config.error_url = 'http://localhost:3000/owner_advert/comeback'
  config.comeback_url = 'http://localhost:3000/owner_advert/comeback'
end
