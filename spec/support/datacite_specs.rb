# frozen_string_literal: true
require "dry/monads"
include Dry::Monads[:result] # Needed to mock the datacite client Success and Failure

def default_datacite_response
  Success("It worked")
end

# rubocop:disable Metrics/MethodLength
def stub_datacite_doi(result: nil)
  @datacite_client_response = result || default_datacite_response

  stub_datacite = if @stub_datacite
                    @stub_datacite
                  else
                    # stubbed = double("Datacite::Client")
                    stubbed = instance_double("Datacite::Client")
                    allow(stubbed).to receive(:update).and_return(@datacite_client_response)
                    @stub_datacite = stubbed
                  end

  @datacite_new_doi ||= "test-doi"
  @datacite_client_doi_body ||= double("datacite_client_doi_body")
  @datacite_client_doi_status ||= true
  @datacite_client_doi_response ||= double("datacite_client_doi_response")

  allow(@datacite_client_doi_body).to receive(:doi).and_return(@datacite_new_doi)
  allow(@datacite_client_doi_response).to receive(:success).and_return(@datacite_client_doi_body)
  allow(@datacite_client_doi_response).to receive(:success?).and_return(@datacite_client_doi_status)
  allow(stub_datacite).to receive(:autogenerate_doi).and_return(@datacite_client_doi_response)
  allow(Datacite::Client).to receive(:new).and_return(stub_datacite)

  stub_datacite
end
# rubocop:enable Metrics/MethodLength

def datacite_register_body(prefix: "10.80021")
  Rails.configuration.datacite.prefix = prefix
  "{\"data\":{\"type\":\"dois\",\"attributes\":{\"prefix\":\"#{prefix}\"}}}"
end

def datacite_update_body(attributes:)
  "{\"data\":{\"attributes\":#{attributes.to_json}}}"
end

def stub_datacite(host: "api.datacite.org", body: datacite_register_body, fixture: "doi_response.json")
  response = File.read(Pathname.new(fixture_path).join(fixture).to_s)

  datacite_env(user: "foo", password: "bar", host: host)
  stub_request(:post, "https://#{host}/dois")
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
  stub_request(:put, "https://#{host}/dois/#{doi}")
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
  Rails.configuration.datacite.user = user
  Rails.configuration.datacite.password = password
  Rails.configuration.datacite.host = host
end
