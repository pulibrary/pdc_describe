# frozen_string_literal: true

def mock_s3_query_service(prefix: nil, data: [])
  @s3_client = instance_double(Aws::S3::Client)
  allow(@s3_client).to receive(:head_object)
  allow(@s3_client).to receive(:delete_object)
  allow(@s3_client).to receive(:put_object)

  @s3_query_service = instance_double(S3QueryService,
                                      prefix: prefix,
                                      client: @s3_client,
                                      client_s3_files: data,
                                      data_profile: { objects: data, ok: true })

  allow(S3QueryService).to receive(:new).and_return(@s3_query_service)
end

RSpec.configure do |config|
  config.before(:suite) do
    RSpec::Mocks.with_temporary_scope do
      mock_s3_query_service
    end
  end
end
