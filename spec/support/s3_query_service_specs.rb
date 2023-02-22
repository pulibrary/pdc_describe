# frozen_string_literal: true

def stub_s3(data: [], bucket_url: nil)
  @s3_client = instance_double(Aws::S3::Client)
  allow(@s3_client).to receive(:head_object)
  allow(@s3_client).to receive(:delete_object)

  fake_s3_query = double(S3QueryService, data_profile: { objects: data, ok: true }, client: @s3_client, client_s3_files: data)
  allow(fake_s3_query).to receive(:bucket_name).and_return("example-bucket")
  allow(fake_s3_query).to receive(:file_count).and_return(data.length)
  allow(fake_s3_query).to receive(:delete_s3_object)
  allow(fake_s3_query).to receive(:publish_files).and_return([])
  allow(S3QueryService).to receive(:new).and_return(fake_s3_query)

  mock_bucket(bucket_url)

  fake_s3_query
end

def mock_bucket(bucket_url)
  if bucket_url.present?
    # Also stub ActiveStorage calls to the bucket
    stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    stub_request(:delete, /#{bucket_url}/).to_return(status: 200)
  end
end
