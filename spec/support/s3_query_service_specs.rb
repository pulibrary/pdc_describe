# frozen_string_literal: true

def stub_s3(data: [], bucket_url: nil, prefix: "10.34770/123-abc/1/", bucket_name: "example-bucket")
  @s3_client = instance_double(Aws::S3::Client)
  allow(@s3_client).to receive(:head_object)
  allow(@s3_client).to receive(:delete_object)
  allow(@s3_client).to receive(:put_object)

  fake_s3_query = instance_double(S3QueryService, data_profile: { objects: data, ok: true }, client: @s3_client,
                                                  client_s3_files: data, prefix:, count_objects: data.count)
  mock_methods(fake_s3_query, data, bucket_name)
  allow(S3QueryService).to receive(:new).and_return(fake_s3_query)

  mock_bucket(bucket_url)

  fake_s3_query
end

def mock_methods(fake_s3_query, data, bucket_name)
  allow(fake_s3_query).to receive(:bucket_name).and_return(bucket_name)
  allow(fake_s3_query).to receive(:file_count).and_return(data.length)
  allow(fake_s3_query).to receive(:delete_s3_object)
  allow(fake_s3_query).to receive(:create_directory)
  allow(fake_s3_query).to receive(:publish_files).and_return([])
  allow(fake_s3_query).to receive(:upload_file).and_return(true)
  allow(fake_s3_query).to receive(:md5).and_return(nil)
  allow(fake_s3_query).to receive(:last_response).and_return Aws::S3::Types::PutObjectOutput.new(etag: "\"abc123\"")
end

def mock_bucket(bucket_url)
  if bucket_url.present?
    # Also stub ActiveStorage calls to the bucket
    stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
  end
end
