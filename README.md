# Przelewy24Payment

It's rails gem to integrate polish payment method: przelewy24.pl

Gem version 0.2.0 on [rubygems](https://rubygems.org/gems/przelewy24_payment) support API version 3.2

## Installation

Add this line to your application's Gemfile:

    gem 'przelewy24_payment'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install przelewy24_payment

After this create przelewy24_payment config:

    $ rails g przelewy24_payment:install

And you can there "config/initializers/przelewy24_payment.rb" setup your settings:

```ruby
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

```

Test connection
```
rake przelewy24_payment:test_connection
```
## Usage

Your controller e.g 'PaymentController' should only include:

```ruby
class YourPaymentController < ApplicationController
  include Przelewy24PaymentController
  ...
```

And you should also have this methods in your payment controller:

```ruby
class YourPaymentController < ApplicationController
  include Przelewy24PaymentController
  ...

  # after success payemnt this method will be trigger
  # so you can do whatever you want
  def payment_success(payment_params)
    # payment_params returns hash with:
    # p24_merchant_id
    # p24_pos_id
    # p24_session_id
    # p24_order_id
    # p24_amount
    # p24_currency
    # p24_method
    # p24_sign
    # p24_karta
    # payment_id

    # e.g
    # payment = Payment.find_by_session_id(payment_params[:p24_session_id])
  end

  # after error payment this method will be trigger
  # so you can do whatever you want
  def payment_error(payment_params, code, description)
    # payment_params returns hash with:
    # p24_merchant_id
    # p24_pos_id
    # p24_session_id
    # p24_order_id
    # p24_amount
    # p24_currency
    # p24_method
    # p24_sign
    # p24_karta
    # payment_id
    #
    # code return error code
    # description return error description
  end

  # method to setup params to verify it final verifyciation
  # so you can do whatever you want
  def payment_verify(response_params)
    # e.g:
    # you must return hash with amount which was save in your db and your crc_key
    payment = Payment::Payment.where(session_id: response_params['p24_session_id']).first
    if payment
      { amount: payment.amount, crc_key: Przelewy24Payment.crc_key }
    else
      {}
    end
  end
```

Last step, on your payment view e.g 'app/views/YourController/your_payment.html.haml' you should add:

```ruby
= payment_button(@data)
```

And also on your payment controller you should specify @data hash e.g:

```ruby
class YourPaymentController < ApplicationController
  include Przelewy24PaymentController
  ...

  def your_payment
    session_id = Przelewy24Payment.friendly_token[0,20] # assign this to payment
    @data = { :session_id =>  session_id,
              :description => "opis",
              :amount => 1.23,
              :email => 'payment@example.com',
              :country => 'PL',
              # adding this params, you overwrite your config settings so this param is optional
              # :merchant_id => merchant_id
              # :pos_id => pos_id
              # :api_version => api_version,
              # :crc_key => crc_key,
              # :currency => currency,
              # :country => country,
              # :url_return => url_return,
              # :url_status => url_status,

              # other optional params
              # :language => pl/en/de/es/it
              # :method => method,
              # :client => 'Adam Nowak',
              # :address => 'Powstancow 22/2',
              # :zipcode => '53-456',
              # :city => 'Wroclaw',
              # :phone => '481321132123',
              # :time_limit => INT,
              # :wait_for_result => INT,
              # :channel => INT,
              # :shipping => INT,
              # :transfer_label => STRING(20)
              # :encoding => ISO-8859-2/UTF-8/Windows-1250

            }
  end

  ...

```

Finish :)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
