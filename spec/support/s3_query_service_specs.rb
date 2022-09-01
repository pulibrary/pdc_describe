# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each) do
    @s3_query_service = instance_double(S3QueryService)
    @data_profile = {
      objects: []
    }

    allow(@s3_query_service).to receive(:data_profile).and_return(@data_profile)
    allow(S3QueryService).to receive(:new).and_return(@s3_query_service)
  end

  config.before(:each, mock_s3_query_service: false) do
    @s3_bucket = "https://example-bucket.s3.amazonaws.com/"

    stub_request(:get, /#{@s3_bucket}/).to_return(
      status: 200
    )
    allow(S3QueryService).to receive(:new).and_call_original
  end
end
