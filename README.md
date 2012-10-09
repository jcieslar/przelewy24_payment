# Przelewy24Payment

It's rails gem to integrate polish payment method: przelewy24.pl

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
  config.seller_id = 'your_seller_id'
  config.language = 'pl'
  config.mode = :development
  config.error_url = 'http://localhost:3000/your_payment/comeback'
  config.comeback_url = 'http://localhost:3000/your_payment/comeback'
end
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
  def payment_success(payment_params)
    # payment_params returns hash with:
    # p24_session_id
    # p24_order_id
    # p24_kwota
    # p24_karta
    # p24_order_id_full
    # p24_crc

    # e.g
    # payment = Payment.find_by_session_id(payment_params[:p24_session_id])
  end

  # after error payemnt this method will be trigger
  def payment_error(payment_params, code, description)
    # payment_params returns hash with:
    # p24_session_id
    # p24_order_id
    # p24_kwota
    # p24_error_code
    # p24_order_id_full
    # p24_crc
    #
    # code return error code
    # description return error description
  end

  def payment_verify(response_params)
    # e.g:
    # payment = Payment.find_by_session_id(response_params[:p24_session_id])

    # you must return hash with amount which was save in your db and optional if you use your crc_key
    return data = { :amount => payment.value }

    #or

    # optional variant:
    return data = { :amount => your_payment_value, :crc_key => your_crc_key }
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
    session_id = Przelewy24Payment.friendly_token[0,20]
    value = give_your_amount
    @data = { :session_id =>  session_id,
              :description => "opis",
              :value => value,
              :client => 'Adam Nowak',
              :address => 'Powstancow 22/2',
              :zipcode => '53-456',
              :city => 'Wroclaw',
              :country => 'Polska',
              :email => 'payment@example.com',
              # adding this params, you overwrite your config settings so this param is optional
              # :language => 'pl',
              # :crc => your_crc_key,
              # :seller_id => seller_id
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
