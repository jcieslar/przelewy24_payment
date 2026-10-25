# frozen_string_literal: true

require "spec_helper"
require "rails/generators/test_case"
require "generators/przelewy24_payment/install/install_generator"
require "tmpdir"

RSpec.describe Przelewy24Payment::Generators::InstallGenerator do
  let(:destination) { Dir.mktmpdir }

  before do
    FileUtils.mkdir_p("#{destination}/config")
    File.write("#{destination}/config/routes.rb", "Rails.application.routes.draw do\nend\n")
    allow_any_instance_of(described_class).to receive(:sleep)
  end

  after { FileUtils.remove_entry(destination) }

  def capture_output
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end

  def run_generator = described_class.start([], destination_root: destination)

  it "creates the initializer, migrations and route" do
    run_generator
    expect(File.read("#{destination}/config/initializers/przelewy24_payment.rb")).to include("Przelewy24Payment.configure")
    migrations = Dir["#{destination}/db/migrate/*"].map { |f| File.basename(f) }
    expect(migrations.size).to eq(3)
    expect(migrations.join).to include("create_przelewy24_payments", "create_przelewy24_refunds", "create_przelewy24_subscriptions")
    expect(File.read("#{destination}/config/routes.rb")).to include('mount Przelewy24Payment::Engine => "/przelewy24"')
  end

  it "mounts the engine at a custom path" do
    described_class.start([ "--mount-path=payments/p24/" ], destination_root: destination)
    expect(File.read("#{destination}/config/routes.rb")).to include('mount Przelewy24Payment::Engine => "/payments/p24"')
  end

  it "prints the real webhook path in the post-install notes" do
    output = capture_output { described_class.start([ "--mount-path=/payments/p24" ], destination_root: destination) }
    expect(output).to include("POST /payments/p24/webhooks/status")
  end

  it "can skip the subscriptions migration" do
    described_class.start([ "--skip-subscriptions" ], destination_root: destination)
    migrations = Dir["#{destination}/db/migrate/*"].map { |f| File.basename(f) }
    expect(migrations.size).to eq(2)
    expect(migrations.join).not_to include("subscriptions")
  end

  it "does not mount the engine twice" do
    2.times { run_generator }
    expect(File.read("#{destination}/config/routes.rb").scan("Przelewy24Payment::Engine").size).to eq(1)
  end
end
