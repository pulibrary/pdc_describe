# frozen_string_literal: true
require "rails_helper"

RSpec.describe "DOI", type: :model, mock_ezid_api: true do
  let(:client) do
    Datacite::Client.new(username: ENV["DATACITE_USER"],
                         password: ENV["DATACITE_PASSWORD"],
                         host: ENV["DATACITE_HOST"])
  end

  let(:prefix) { "10.80021" }
  let(:doi) { "10.80021/f91s-fg71" }

  let(:minimum_register_attributes) do
    {
      "event" => "register",
      "titles" => [{ "title" => "testing doi" }],
      "creators" => [{
        "name" => "DataCite Metadata Working Group"
      }],
      "publisher" => "DataCite e.V.",
      "publicationYear" => "2016",
      "types" => {
        "resourceTypeGeneral" => "Text",
        "resourceType" => "acb"
      },
      "url" => "https://schema.datacite.org/meta/kernel-4.0/index.html"
    }
  end

  let(:minimum_publish_attributes) do
    {
      "event" => "publish",
      "titles" => [{ "title" => "testing doi" }],
      "creators" => [{
        "name" => "DataCite Metadata Working Group"
      }],
      "publisher" => "DataCite e.V.",
      "publicationYear" => "2016",
      "types" => {
        "resourceTypeGeneral" => "Text",
        "resourceType" => "acb"
      },
      "url" => "https://schema.datacite.org/meta/kernel-4.0/index.html"
    }
  end

  let(:xml_attributes) do
    work = FactoryBot.create(:shakespeare_and_company_work)
    ValidDatacite::Resource.new_from_json(work.data_cite).to_xml
  end

  let(:minimum_xml_publish_attributes) do
    {
      "event" => "publish",
      "xml" => Base64.encode64(xml_attributes),
      "url" => "https://schema.datacite.org/meta/kernel-4.0/index.html" # this should be a link to the item in PDC-discovery
    }
  end

  describe "SPIKE" do
    it "mints a new DOI" do
      stub_datacite(host: "api.datacite.org", body: datacite_register_body(prefix: prefix))
      #
      # Comment out the above stub and uncomment the below code to send a real request and create an DOI
      # you must have the datacite host, user name, and password in your environment
      #
      # WebMock.enable_net_connect!
      result = client.autogenerate_doi(prefix: prefix)
      doi = result.either(
              ->(response) { response.doi },
              ->(response) { raise("Something went wrong", response.status) }
            )
      puts doi
      expect(doi).to be_present
    end

    it "registers an existing DOI" do
      body = datacite_update_body(attributes: minimum_register_attributes)

      stub_datacite_update(doi: doi, body: body, fixture: "doi_register_response.json", host: "api.datacite.org")
      #
      # Comment out the above stub and uncomment the below code to send a real request to register a DOI
      # you must have the datacite host, user name, and password in your environment
      # set the doi above to any draft doi
      #
      # WebMock.enable_net_connect!

      # Register the DOI with the minimum attributes needed to register the item
      result = client.update(id: doi, attributes: minimum_register_attributes)

      data = result.either(
                   ->(response) { response.body["data"] },
                   ->(response) { raise("Something went wrong", response.status) }
                 )
      expect(data["attributes"]["state"]).to eq("registered")
    end

    it "Updates and existing doi" do
      update_attributes = { "titles" => [{ "title" => "testing doi update" }] }
      body = datacite_update_body(attributes: update_attributes)

      stub_datacite_update(doi: doi, body: body, fixture: "doi_update_response.json", host: "api.datacite.org")
      #
      # Comment out the above stub and uncomment the below code to send a real request and update a DOI's title
      # you must have the datacite host, user name, and password in your environment
      # set the doi above to any existing doi
      #
      # WebMock.enable_net_connect!

      result = client.update(id: doi, attributes: update_attributes)

      data = result.either(
        ->(response) { response.body["data"] },
        ->(response) { raise("Something went wrong", response.status) }
      )
      expect(data["attributes"]["titles"].first["title"]).to eq("testing doi update")
    end

    it "publishes an existing DOI" do
      stub_datacite_update(doi: doi, body: datacite_update_body(attributes: minimum_publish_attributes), fixture: "doi_publish_response.json", host: "api.datacite.org")
      #
      # Comment out the above stub and uncomment the below code to send a real request and publish a DOI
      # you must have the datacite host, user name, and password in your environment
      # set the doi above to an unpublished doi
      #
      # WebMock.enable_net_connect!

      # Publish the DOI with the minimum attributes needed to publish the item
      result = client.update(id: doi, attributes: minimum_publish_attributes)

      data = result.either(
        ->(response) { response.body["data"] },
        ->(response) { raise("Something went wrong", response.status) }
      )
      expect(data["attributes"]["state"]).to eq("findable")
    end

    it "publishes an existing DOI with xml" do
      stub_datacite_update(doi: doi, body: datacite_update_body(attributes: minimum_xml_publish_attributes), fixture: "doi_publish_response.json", host: "api.datacite.org")
      #
      # Comment out the above stub and uncomment the below code to send a real request and publish a DOI
      # you must have the datacite host, user name, and password in your environment
      # set the doi above to an unpublished doi
      #
      # WebMock.enable_net_connect!

      # Publish the DOI with the minimum attributes needed to publish the item
      result = client.update(id: doi, attributes: minimum_xml_publish_attributes)

      data = result.either(
        ->(response) { response.body["data"] },
        ->(response) { raise("Something went wrong", response.status) }
      )
      expect(data["attributes"]["state"]).to eq("findable")
    end
  end
end
