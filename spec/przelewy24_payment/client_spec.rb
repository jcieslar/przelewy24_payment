# frozen_string_literal: true

require "spec_helper"

RSpec.describe Przelewy24Payment::Client do
  subject(:client) { Przelewy24Payment.client }

  let(:base) { "https://sandbox.przelewy24.pl/api/v1" }
  let(:json) { { "Content-Type" => "application/json" } }

  it "authenticates with pos id and api key" do
    stub = stub_request(:get, "#{base}/testAccess")
           .with(basic_auth: [ "12345", "api-key" ])
           .to_return(body: { data: true }.to_json, headers: json)
    expect(client.test_access).to be true
    expect(stub).to have_been_requested
  end

  {
    400 => Przelewy24Payment::ValidationError, 401 => Przelewy24Payment::AuthenticationError,
    404 => Przelewy24Payment::NotFoundError, 500 => Przelewy24Payment::ServerError
  }.each do |status, error|
    it "maps HTTP #{status} to #{error}" do
      stub_request(:get, "#{base}/testAccess").to_return(status: status, body: { error: "boom" }.to_json, headers: json)
      expect { client.test_access }.to raise_error(error, /boom/) { |e| expect(e.status).to eq(status) }
    end
  end

  it "wraps transport errors" do
    stub_request(:get, "#{base}/testAccess").to_timeout
    expect { client.test_access }.to raise_error(Przelewy24Payment::ConnectionError)
  end

  it "fails fast on missing credentials" do
    Przelewy24Payment.reset_configuration!
    expect { Przelewy24Payment.client.test_access }.to raise_error(Przelewy24Payment::ConfigurationError)
  end

  it "publishes request events" do
    stub_request(:get, "#{base}/testAccess").to_return(body: { data: true }.to_json, headers: json)
    events = []
    ActiveSupport::Notifications.subscribed(->(*args) { events << args.first }, "request.przelewy24") { client.test_access }
    expect(events).to eq([ "request.przelewy24" ])
  end
end
