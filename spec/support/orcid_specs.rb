# frozen_string_literal: true
require "sinatra/base"

# This sets up a little local server to respond to ORCID ajax requests
# This is utilized to test the javascript that parses the ajax response and puts the ORCID family name and given name into the form
#  The data returned is a simplified version of the data returned from ORCID.  If more data than just the name is needed the data here will need to be updated
#  The response is hard-coded for a few known values and defaults to "Sally Smith" for all others.
#
# This Fake was modeled on the information in this article: https://thoughtbot.com/blog/using-capybara-to-test-javascript-that-makes-http
class FakeOrcidIntegration < Sinatra::Base
  def self.boot
    instance = new
    Capybara::Server.new(instance).tap(&:boot)
  end

  get "/:orcid" do |orcid|
    content_type(:js)
    callback = params[:callback]
    data = {
      "orcid-identifier" => {
        "uri" => "http://orcid.org/#{orcid}",
        "path" => orcid,
        "host" => "orcid.org"
      },
      "person" => {
        "name" => {
          "given-names" => { "value" => "Sally" },
          "family-name" => { "value" => "Smith" }
        }
      }
    }

    case orcid
    when "0000-0001-8965-6820"
      data["person"]["name"]["given-names"]["value"] = "Carmen"
      data["person"]["name"]["family-name"]["value"] = "Valdez"
    when "0000-0001-5443-5964"
      data["person"]["name"]["given-names"]["value"] = "Melody"
      data["person"]["name"]["family-name"]["value"] = "Loya"
    end

    "#{callback}(#{data.to_json});"
  end
end

server = FakeOrcidIntegration.boot
ORCID_URL = "http://#{[server.host, server.port].join(':')}"
