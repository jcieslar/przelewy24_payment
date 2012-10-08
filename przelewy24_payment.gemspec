# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'przelewy24_payment/version'

Gem::Specification.new do |gem|
  gem.name          = "przelewy24_payment"
  gem.version       = Przelewy24Payment::VERSION
  gem.authors       = ["Jakub Cieślar"]
  gem.email         = ["cieslar.jakub@gmail.com"]
  gem.description   = %q{Integration with polish payment method: Przelewy24}
  gem.summary       = %q{Integration with polish payment method: Przelewy24}
  gem.homepage      = "https://github.com/jcieslar/przelewy24_payment"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
