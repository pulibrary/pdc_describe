# frozen_string_literal: true
require "rails_helper"

RSpec.describe DspaceFileCopyJob, type: :job do
  include ActiveJob::TestHelper

  let(:s3_file) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/test_key", size: 10_759, filename_display: "abc/123/#{work.id}/test_key" }
  subject(:job) { described_class.perform_later(s3_file_json: s3_file.to_json, work_id: work.id, migration_snapshot_id: migration_snapshot.id) }
  let(:work) { FactoryBot.create :draft_work }
  let(:fake_s3_service) { instance_double(S3QueryService, bucket_name: "work-bucket", prefix: "abc/123/#{work.id}/") }
  let(:migration_snapshot) { MigrationUploadSnapshot.create(files: [s3_file], work: work, url: "example.com") }

  before do
    allow(Work).to receive(:find).and_return(work)

    fake_completion =  instance_double(Seahorse::Client::Response, "successful?": true)
    allow(fake_s3_service).to receive(:copy_file).and_return(fake_completion)
    allow(work).to receive(:s3_query_service).and_return(fake_s3_service)
  end

  it "runs an aws copy" do
    perform_enqueued_jobs { job }
    expect(fake_s3_service).to have_received(:copy_file).with(size: 10_759, source_key: "example-bucket-dspace/10-34770/ackh-7y71/test_key",
                                                              target_bucket: "work-bucket", target_key: "abc/123/#{work.id}/test_key")
  end

  context "when the files is a directory" do
    let(:s3_file) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/dir/", size: 0, filename_display: "abc/123/#{work.id}/dir/" }

    it "copies directory" do
      perform_enqueued_jobs { job }
      expect(fake_s3_service).to have_received(:copy_file).with(source_key: "example-bucket-dspace/10-34770/ackh-7y71/dir/",
                                                                target_bucket: "work-bucket",
                                                                target_key: "abc/123/#{work.id}/dir/", size: 0)
    end
  end

  context "when the file is not part of the migration" do
    let(:s3_file2) { FactoryBot.build :s3_file, filename: "10-34770/ackh-7y71/abc", size: 1, filename_display: "abc/123/#{work.id}/abc" }
    subject(:job) { described_class.perform_later(s3_file_json: s3_file2.to_json, work_id: work.id, migration_snapshot_id: migration_snapshot.id) }

    it "Sends the error to HoneyBadger" do
      allow(Honeybadger).to receive(:notify)
      perform_enqueued_jobs { job }
      expect(fake_s3_service).to have_received(:copy_file).with(source_key: "example-bucket-dspace/10-34770/ackh-7y71/abc",
                                                                target_bucket: "work-bucket",
                                                                target_key: "abc/123/#{work.id}/abc", size: 1)

      expect(Honeybadger).to have_received(:notify)
    end
  end
end
