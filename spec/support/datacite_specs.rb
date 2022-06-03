# frozen_string_literal: true
def stub_datacite(user: "foo", password: "bar", encoded_user: "Zm9vOmJhcg==", host: "api.datacite.org")
  response = File.read(Pathname.new(fixture_path).join("doi_response.json").to_s)

  datacite_env(user: user, password: password, host: host)
  stub_request(:post, ENV["DATACITE_URL"])
    .with(
    body: "{\"data\":{\"type\":\"dois\",\"attributes\":{\"prefix\":\"10.34770\"}}}",
    headers: {
      "Accept" => "*/*",
      "Accept-Encoding" => "gzip;q=1.0,deflate;q=0.6,identity;q=0.3",
      "Authorization" => "Basic #{encoded_user}",
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
