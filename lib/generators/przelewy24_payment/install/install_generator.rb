# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module Przelewy24Payment
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)
      desc "Installs Przelewy24Payment: initializer, migrations and webhook routes."

      class_option :mount_path, type: :string, default: "/przelewy24",
                                desc: "Path where the webhook engine is mounted"
      class_option :skip_subscriptions, type: :boolean, default: false,
                                        desc: "Do not generate the subscriptions migration"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_initializer
        template "initializer.rb.tt", "config/initializers/przelewy24_payment.rb"
      end

      def copy_migrations
        migration_template "create_przelewy24_payments.rb.tt", "db/migrate/create_przelewy24_payments.rb",
                           migration_version: migration_version
        tables = options[:skip_subscriptions] ? %w[refunds] : %w[refunds subscriptions]
        tables.each do |name|
          sleep 1 # keep migration timestamps unique
          migration_template "create_przelewy24_#{name}.rb.tt", "db/migrate/create_przelewy24_#{name}.rb",
                             migration_version: migration_version
        end
      end

      def mount_engine
        return if File.read(File.join(destination_root, "config/routes.rb")).include?("Przelewy24Payment::Engine")

        route "mount Przelewy24Payment::Engine => #{mount_path.inspect}"
      end

      def show_readme
        return unless behavior == :invoke

        say File.read(File.join(self.class.source_root, "README")).gsub("{{mount_path}}", mount_path)
      end

      private

      def mount_path
        path = options[:mount_path].to_s
        path = "/#{path}" unless path.start_with?("/")
        path.chomp("/").presence || "/"
      end

      def migration_version
        "[#{ActiveRecord::Migration.current_version}]"
      end
    end
  end
end
