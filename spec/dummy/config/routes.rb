# frozen_string_literal: true

Rails.application.routes.draw do
  mount Przelewy24Payment::Engine => "/przelewy24"
end
