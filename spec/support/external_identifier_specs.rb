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

  get "/works/:id/file-list" do |id|
    files = []
    files << {
      filename: "10.34770/123-abc/#{id}/SCoData_combined_v1_2020-07_README.txt",
      filename_display: "SCoData_combined_v1_2020-07_README.txt",
      last_modified: "2022-10-20T20:59:59.000Z",
      last_modified_display: "10/20/2022 04:59 PM",
      size: 123,
      checksum: "12345",
      url: "/works/#{id}/download?filename=SCoData_combined_v1_2020-07_README.txt"
    }
    files << {
      filename: "10.34770/123-abc/#{id}/SCoData_combined_v1_2020-07_datapackage.json",
      filename_display: "SCoData_combined_v1_2020-07_datapackage.json",
      last_modified: "2022-11-20T20:59:59.000Z",
      last_modified_display: "11/20/2022 04:59 PM",
      size: 123,
      checksum: "12345",
      url: "/works/#{id}/download?filename=SCoData_combined_v1_2020-07_datapackage.json"
    }
    files << {
      filename: "10.34770/123-abc/#{id}/us_covid_2019.csv",
      filename_display: "us_covid_2019.csv",
      last_modified: "2022-12-20T20:59:59.000Z",
      last_modified_display: "12/20/2022 04:59 PM",
      size: 123,
      checksum: "12345",
      url: "/works/#{id}/download?filename=us_covid_2019.csv"
    }
    files << {
      filename: "10.34770/123-abc/#{id}/us_covid_2020.csv",
      filename_display: "us_covid_2020.csv",
      last_modified: "2022-12-20T20:59:59.000Z",
      last_modified_display: "12/20/2022 04:59 PM",
      size: 123,
      checksum: "12345",
      url: "/works/#{id}/download?filename=us_covid_2020.csv"
    }
    files.to_json
  end
end

server = FakeIdentifierIntegration.boot
ORCID_URL = "http://#{[server.host, server.port].join(':')}/orcid"
ROR_URL = "http://#{[server.host, server.port].join(':')}/ror"
WORKS_FILE_LIST_URL = "http://#{[server.host, server.port].join(':')}/works/place-holder/file-list"
