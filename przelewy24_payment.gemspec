# frozen_string_literal: true

require_relative "lib/przelewy24_payment/version"

Gem::Specification.new do |spec|
  spec.name = "przelewy24_payment"
  spec.version = Przelewy24Payment::VERSION
  spec.authors = [ "Jakub Cieślar" ]
  spec.email = [ "cieslar.jakub@gmail.com" ]

  spec.summary = "Przelewy24 payments for Rails: REST API client, webhooks engine and generators."
  spec.description = "Rails engine for the Przelewy24 REST API v1: transaction registration, " \
                     "signed webhook handling with verification, refunds, payment methods, " \
                     "install generator and test helpers."
  spec.homepage = "https://github.com/jcieslar/przelewy24_payment"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/master/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{app,config,lib}/**/*", "CHANGELOG.md", "LICENSE.txt", "README.md"]
  spec.require_paths = [ "lib" ]

  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "rails", ">= 7.1", "< 9.0"
end
