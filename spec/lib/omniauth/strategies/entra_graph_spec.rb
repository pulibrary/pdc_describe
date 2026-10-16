# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib", "omniauth", "strategies", "entra_graph")

RSpec.describe OmniAuth::Strategies::EntraGraph do
  subject(:strategy) { described_class.new(->(_env) { [200, {}, []] }) }

  around do |example|
    original = ENV.to_hash
    example.run
    ENV.replace(original)
  end

  before do
    allow(strategy).to receive(:request).and_return(instance_double(Rack::Request, params: {}))
  end

  it "points authorize and token URLs at the tenant Graph OAuth endpoints" do
    ENV["ENTRA_CLIENT_ID"] = "client-id"
    ENV["ENTRA_CLIENT_SECRET"] = "client-secret"
    ENV["ENTRA_TENANT_ID"] = "tenant-guid"

    strategy.client

    expect(strategy.options.client_options.authorize_url).to eq("https://login.microsoftonline.com/tenant-guid/oauth2/v2.0/authorize")
    expect(strategy.options.client_options.token_url).to eq("https://login.microsoftonline.com/tenant-guid/oauth2/v2.0/token")
    expect(strategy.options.authorize_params.scope).to eq(described_class::GRAPH_SCOPE)
    expect(strategy.options.client_id).to eq("client-id")
    expect(strategy.options.client_secret).to eq("client-secret")
  end

  it "uses the common tenant when ENTRA_TENANT_ID is blank" do
    ENV["ENTRA_CLIENT_ID"] = "client-id"
    ENV["ENTRA_CLIENT_SECRET"] = "client-secret"
    ENV["ENTRA_TENANT_ID"] = ""

    strategy.client

    expect(strategy.options.client_options.authorize_url).to eq("https://login.microsoftonline.com/common/oauth2/v2.0/authorize")
  end

  it "raises when the client id or secret is missing" do
    ENV.delete("ENTRA_CLIENT_ID")
    ENV["ENTRA_CLIENT_SECRET"] = "client-secret"

    expect { strategy.client }.to raise_error(KeyError, /ENTRA_CLIENT_ID/)
  end
end
