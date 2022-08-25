# frozen_string_literal: true
require "dry/monads"
include Dry::Monads[:result] # Needed to mock the datacite client Success and Failure

def stub_datacite_doi(result: Success("It worked"))
  stub_datacite = instance_double("Datacite::Client")
  allow(stub_datacite).to receive(:update).and_return(result)
  allow(Datacite::Client).to receive(:new).and_return(stub_datacite)
  stub_datacite
end

def datacite_register_body(prefix: "10.80021")
  ENV["DATACITE_PREFIX"] = prefix
  "{\"data\":{\"type\":\"dois\",\"attributes\":{\"prefix\":\"#{prefix}\"}}}"
end

def datacite_update_body(attributes:)
  "{\"data\":{\"attributes\":#{attributes.to_json}}}"
end

def stub_datacite(host: "api.datacite.org", body: datacite_register_body, fixture: "doi_response.json")
  response = File.read(Pathname.new(fixture_path).join(fixture).to_s)

  datacite_env(user: "foo", password: "bar", host: host)
  stub_request(:post, ENV["DATACITE_URL"])
    .with(
    body: body,
    headers: {
      "Accept" => "*/*",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Basic Zm9vOmJhcg==",
      "Content-Type" => "application/vnd.api+json",
      "User-Agent" => "Datacite Ruby client version 0.3.0"
    }
  )
    .to_return(status: 200, body: response, headers: { "Content-Type" => "application/json" })
end

def stub_datacite_update(doi:, body:, fixture:, host: "api.datacite.org")
  response = File.read(Pathname.new(fixture_path).join(fixture).to_s)
  datacite_env(user: "foo", password: "bar", host: host)
  stub_request(:put, "https://api.datacite.org/dois/#{doi}")
    .with(
           body: body,
           headers: {
             "Accept" => "*/*",
             "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
             "Authorization" => "Basic Zm9vOmJhcg==",
             "Content-Type" => "application/vnd.api+json",
             "User-Agent" => "Datacite Ruby client version 0.3.0"
           }
         )
    .to_return(status: 200, body: response, headers: { "Content-Type" => "application/json" })
end

def datacite_env(user:, password:, host:)
  ENV["DATACITE_USER"] = user
  ENV["DATACITE_PASSWORD"] = password
  ENV["DATACITE_HOST"] = host
  ENV["DATACITE_URL"] = "https://#{ENV['DATACITE_HOST']}/dois"
end
