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
  # https://api.ror.org/organizations/https://ror.org/01bj3aw27 (for ROR look ups by ID)
  # and from https://api.ror.org/?query.advanced=name:Princeton (for ROR queries by name)
  #
  # NOTE: You cannot put `byebug` to step into this code (something to do with different threads
  # of execution) and using `puts` to output to the console does now work either, but you can
  # write to a file and inspect the values that way, for example:
  #   File.write("/path/to/file.txt", "ROR params #{params}\r\n", mode: "a")
  get "/ror*" do
    ror = params["splat"].first
    query = params["query.advanced"]
    content_type(:json)
    callback = params[:callback]
    data = ror.present? ? ror_lookup(ror) : ror_query(query)
    "#{callback}#{data.to_json}"
  end

  def ror_query(_query)
    {
      "number_of_results": 1,
      "items": [{ "id": "https://ror.org/02hvk4n65", "name": "Water Department" }]
    }
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
    when /00hx57361/
      {
        "id": ror,
        "name": "Princeton University"
      }
    when /03vn1ts68/
      {
        "id": ror,
        "name": "Princeton Plasma Physics Laboratory"
      }
    when /037gd6g64/
      {
        "id": ror,
        "name": "Division of Atmospheric and Geospace Sciences"
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
    # Notice that we force "application/json" on the JavaScript call and therefore
    # we must use `content_type :json` in our response as well.
    content_type(:json)

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

    data.to_json
  end
end

server = FakeIdentifierIntegration.boot
ORCID_URL = "http://#{[server.host, server.port].join(':')}/orcid".freeze
ROR_URL = "http://#{[server.host, server.port].join(':')}/ror".freeze
