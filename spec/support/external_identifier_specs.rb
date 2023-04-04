# frozen_string_literal: true
require "sinatra/base"

# This sets up a little local server to respond to ORCID or ROR ajax requests
# This is utilized to test the javascript that parses the ajax response and puts the ORCID family name and given name into the form
#  The data returned is a simplified version of the data returned from ORCID.  If more data than just the name is needed the data here will need to be updated
#  The response is hard-coded for a few known values and defaults to "Sally Smith" for all others.
#
# Similarly, ROR is configured for only a few common lookup values.
#
# This Fake was modeled on the information in this article: https://thoughtbot.com/blog/using-capybara-to-test-javascript-that-makes-http
class FakeIdentifierIntegration < Sinatra::Base
  def self.boot
    instance = new
    Capybara::Server.new(instance).tap(&:boot)
  end

  before do
    response.headers["Access-Control-Allow-Origin"] = "*"
  end

  # Mimic the response we'd get from
  # https://api.ror.org/organizations/https://ror.org/01bj3aw27
  get "/ror/*" do
    ror = params["splat"].first
    content_type(:json)
    callback = params[:callback]
    data = ror_lookup(ror)
    "#{callback}#{data.to_json}"
  end

  # rubocop:disable Metrics/MethodLength
  def ror_lookup(ror)
    case ror
    when /01bj3aw27/
      {
        "id": ror,
        "name": "United States Department of Energy"
      }
    when /021nxhr62/
      {
        "id": ror,
        "name": "National Science Foundation"
      }
    when /018mejw64/
      {
        "id": ror,
        "name": "Deutsche Forschungsgemeinschaft"
      }
    when /027ka1x80/
      {
        "id": ror,
        "name": "National Aeronautics and Space Administration"
      }
    when /01t3wyv61/
      {
        "id": ror,
        "name": "National Institute for Fusion Science"
      }
    else
      {
        "id": ror,
        "name": "Something went wrong"
      }
    end
  end
  # rubocop:enable Metrics/MethodLength

  get "/orcid/:orcid" do |orcid|
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

server = FakeIdentifierIntegration.boot
ORCID_URL = "http://#{[server.host, server.port].join(':')}/orcid"
ROR_URL = "http://#{[server.host, server.port].join(':')}/ror"
