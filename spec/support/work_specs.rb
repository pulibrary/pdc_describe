# frozen_string_literal: true

def mock_s3_client
  @s3_client ||= instance_double(Aws::S3::Client)
  allow(@s3_client).to receive(:head_object)
  allow(@s3_client).to receive(:delete_object)
  allow(@s3_client).to receive(:put_object)

  @s3_client
end

def mock_s3_query_service(prefix: nil, data: [])
  @s3_query_service ||= instance_double(S3QueryService)

  allow(@s3_query_service).to receive(:prefix).and_return(prefix)
  allow(@s3_query_service).to receive(:client).and_return(mock_s3_client)
  allow(@s3_query_service).to receive(:client_s3_files).and_return(data)
  allow(@s3_query_service).to receive(:data_profile).and_return({
                                                                  objects: data,
                                                                  ok: true
                                                                })

  @s3_query_service
end

def mock_s3_query_service_class(prefix: nil, data: [])
  mocked = mock_s3_query_service(prefix: prefix, data: data)
  allow(S3QueryService).to receive(:new).and_return(mocked)
  mocked
end

def mock_attach_file_job
  allow(AttachFileToWorkJob).to receive(:perform_later)
end

RSpec.configure do |config|
  # For mocking AttachFileToWorkJob
  config.add_setting(:mock_attach_file_job, default: false)
  config.before(:context, mock_attach_file_job: true) do
    config.mock_attach_file_job = true
  end
  config.after(:context, mock_attach_file_job: true) do
    config.mock_attach_file_job = false
  end

  # For mocking S3QueryService
  config.add_setting(:mock_s3_query_service_class, default: true)
  config.before(:context, mock_s3_query_service_class: false) do
    config.mock_s3_query_service_class = false
  end
  config.after(:context, mock_s3_query_service_class: false) do
    config.mock_s3_query_service_class = true
  end

  config.before(:suite) do
    RSpec::Mocks.with_temporary_scope do
      if config.mock_attach_file_job
        mock_attach_file_job
      end

      if config.mock_s3_query_service_class
        mock_s3_query_service_class
      end
    end
  end

  config.before(:each) do
    mock_attach_file_job
  end
end
