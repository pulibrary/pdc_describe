# frozen_string_literal: true
require "rails_helper"

RSpec.describe ApprovedFileMoveJob, type: :job do
  include ActiveJob::TestHelper

  subject(:job) do
    described_class.perform_later(work_id: work.id, source_bucket: "example-bucket", source_key: "10.34770/ackh-7y71/1/test_key", target_bucket: "example-bucket-post",
                                  target_key: "10.34770/ackh-7y71/1/test_key", size: 200)
  end
  let(:fake_s3_service) { stub_s3 }
  let(:work) { FactoryBot.create :approved_work }

  before do
    fake_completion = instance_double(Seahorse::Client::Response, "successful?": true)
    allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
    allow(fake_s3_service).to receive(:delete_s3_object).and_return(fake_completion)
    allow(fake_s3_service).to receive(:check_file).and_return(true)
    allow(fake_s3_service.client).to receive(:put_object).and_return(nil)
  end

  it "runs an aws copy and delete" do
    perform_enqueued_jobs { job }
    expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "/example-bucket/10.34770/ackh-7y71/1/test_key",
                                                              target_bucket: "example-bucket-post", target_key: "10.34770/ackh-7y71/1/test_key")
    expect(fake_s3_service).to have_received(:delete_s3_object).with("10.34770/ackh-7y71/1/test_key", bucket: "example-bucket")
    expect(fake_s3_service).to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
    expect(fake_s3_service.client).to have_received(:put_object).with({ bucket: "example-bucket-post", content_length: 0, key: "#{work.doi}/#{work.id}/princeton_data_commons/" })
  end

  context "the copy fails" do
    before do
      fake_completion = instance_double(Seahorse::Client::Response, "successful?": false)
      allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
    end
    it "runs an aws copy, but no delete" do
      expect { perform_enqueued_jobs { job } }.to raise_error(/Error copying \/example-bucket\/10.34770\/ackh-7y71\/1\/test_key to example-bucket-post\/10.34770\/ackh-7y71\/1\/test_key/)
      expect(fake_s3_service).to have_received(:copy_file).with(size: 200, source_key: "/example-bucket/10.34770/ackh-7y71/1/test_key",
                                                                target_bucket: "example-bucket-post", target_key: "10.34770/ackh-7y71/1/test_key")
      expect(fake_s3_service).not_to have_received(:delete_s3_object).with("example-bucket/10.34770/ackh-7y71/1/test_key")
      expect(fake_s3_service).not_to have_received(:delete_s3_object).with(work.s3_object_key, bucket: "example-bucket")
    end
  end
end
