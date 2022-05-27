# frozen_string_literal: true
require "rails_helper"

RSpec.describe "DOI", type: :model do
  describe "SPIKE" do
    let(:response) do
      <<~JSON
        {
          "data": {
            "id": "10.34770/doc-1",
            "type": "dois",
            "attributes": {
              "doi": "10.34770/doc-1",
              "prefix": "10.34770",
              "suffix": "0012",
              "identifiers": [{
                "identifier": "https://doi.org/10.34770/doc-1",
                "identifierType": "DOI"
              }],
              "creators": [],
              "titles": [],
              "publisher": null,
              "container": {},
              "publicationYear": null,
              "subjects": [],
              "contributors": [],
              "dates": [],
              "language": null,
              "types": {},
              "relatedIdentifiers": [],
              "sizes": [],
              "formats": [],
              "version": null,
              "rightsList": [],
              "descriptions": [],
              "geoLocations": [],
              "fundingReferences": [],
              "xml": null,
              "url":null,
              "contentUrl": null,
              "metadataVersion": 1,
              "schemaVersion": "http://datacite.org/schema/kernel-4",
              "source": null,
              "isActive": true,
              "state": "draft",
              "reason": null,
              "created": "2016-09-19T21:53:56.000Z",
              "registered": null,
              "updated": "2019-02-06T14:31:27.000Z"
            },
            "relationships": {
              "client": {
                "data": {
                  "id": "datacite.datacite",
                  "type": "clients"
                }
              },
              "media": {
                "data": []
              }
            }
          },
          "included": [{
            "id": "datacite.datacite",
            "type": "clients",
            "attributes": {
              "name": "DataCite",
              "symbol": "DATACITE.DATACITE",
              "year": 2011,
              "contactName": "DataCite",
              "contactEmail": "support@datacite.org",
              "description": null,
              "domains": "*",
              "url": null,
              "created": "2011-12-07T13:43:39.000Z",
              "updated": "2019-01-02T17:33:06.000Z",
              "isActive": true,
              "hasPassword": true
            },
            "relationships": {
              "provider": {
                "data": {
                  "id": "datacite",
                  "type": "providers"
                }
              },
              "prefixes": {
                "data": [{
                  "id": "10.34770",
                  "type": "prefixes"
                }]
              }
            }
          }]
        }
      JSON
    end

    it "mints a new DOI" do
      stub_request(:post, "https://api.datacite.org/dois")
        .with(
        body: "{\"data\":{\"type\":\"dois\",\"attributes\":{\"prefix\":\"10.34770\"}}}",
        headers: {
          "Accept" => "*/*",
          "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
          "Authorization" => "Basic Zm9vOmJhcg==",
          "Content-Type" => "application/vnd.api+json",
          "User-Agent" => "Datacite Ruby client version 0.3.0"
        }
      )
        .to_return(status: 200, body: response, headers: { "Content-Type" => "application/json" })
      client = Datacite::Client.new(username: "foo",
                                    password: "bar",
                                    host: "api.datacite.org")
      #
      # Comment out the above stub and uncomment the below code to send a real request and create an DOI
      # you must have the datacite user name and password in your environment
      #
      # WebMock.enable_net_connect!
      # client = Datacite::Client.new(username: ENV["DATACITE_USER"],
      #   password: ENV["DATACITE_PASSWORD"],
      #   host: "api.datacite.org")

      result = client.autogenerate_doi(prefix: "10.34770")
      doi = result.either(
              ->(response) { response.doi },
              ->(response) { raise("Something went wrong", response.status) }
            )
      puts doi
      expect(doi).to be_present
    end
  end
end
