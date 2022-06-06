# frozen_string_literal: true
require "rails_helper"

RSpec.describe "DOI", type: :model do
  describe "SPIKE" do
    it "mints a new DOI" do
      stub_datacite(user: "foo", password: "bar", encoded_user: "Zm9vOmJhcg==", host: "api.datacite.org")
      #
      # Comment out the above stub and uncomment the below code to send a real request and create an DOI
      # you must have the datacite host, user name, and password in your environment
      #
      # WebMock.enable_net_connect!
      client = Datacite::Client.new(username: ENV["DATACITE_USER"],
                                    password: ENV["DATACITE_PASSWORD"],
                                    host: ENV["DATACITE_HOST"])

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
