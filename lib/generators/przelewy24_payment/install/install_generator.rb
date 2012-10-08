class Przelewy24Payment::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('../templates', __FILE__)

  def add_config
    template "przelewy24_payment.rb", "config/initializers/przelewy24_payment.rb"
  end

end
