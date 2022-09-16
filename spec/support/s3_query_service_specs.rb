# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    @s3_query_service = instance_double(S3QueryService)
    @data_profile = {
      objects: []
    }
    @s3_client = instance_double(Aws::S3::Client)

    allow(@s3_query_service).to receive(:data_profile).and_return(@data_profile)
    allow(@s3_query_service).to receive(:bucket_name).and_return("example-bucket")
    allow(@s3_query_service).to receive(:client).and_return(@s3_client)
    allow(S3QueryService).to receive(:new).and_return(@s3_query_service)
  end

  config.before(:each, mock_s3_query_service: false) do
    @s3_bucket_url = "https://example-bucket.s3.amazonaws.com/"

    @s3_object_response_headers = {
      'Accept-Ranges': "bytes",
      'Content-Length': 12,
      'Content-Type': "text/plain",
      'ETag': "6805f2cfc46c0f04559748bb039d69ae",
      'Last-Modified': Time.parse("Thu, 15 Dec 2016 01:19:41 GMT")
    }

    @s3_object_url = "https://example-bucket.s3.amazonaws.com/10.34770/pe9w-x904/"
    stub_request(:get, /#{Regexp.escape(@s3_object_url)}/).to_return(status: 200, body: "test_content", headers: @s3_object_response_headers)

    @s3_bucket_query_url = "https://example-bucket.s3.amazonaws.com/?list-type=2&max-keys=1000&prefix=10.34770/doc-1/"
    stub_request(:get, /#{Regexp.escape(@s3_bucket_query_url)}/).to_return(status: 200)

    stub_request(:get, "https://example-bucket.s3.amazonaws.com/test_key").to_return(status: 200, body: "test_content", headers: @s3_object_response_headers)
    stub_request(:get, /#{Regexp.escape(@s3_bucket_url)}/).to_return(status: 200, body: "test_content", headers: @s3_object_response_headers)

    stub_request(:get, /#{Regexp.escape(@s3_bucket_url)}/).to_return(status: 200, body: "test_content", headers: @s3_object_response_headers)

    allow(S3QueryService).to receive(:new).and_call_original
  end
end
