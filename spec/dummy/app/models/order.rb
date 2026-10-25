# frozen_string_literal: true

class Order < ActiveRecord::Base
  include Przelewy24Payment::Payable
end
