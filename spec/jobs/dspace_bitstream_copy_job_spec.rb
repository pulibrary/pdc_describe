# frozen_string_literal: true
require "rails_helper"
require "sidekiq/testing/inline"

RSpec.describe DspaceBitstreamCopyJob, type: :job do
  include ActiveJob::TestHelper

  let(:s3_files_json) do
    "[{\"filename\":\"/tmp/dspace_download/#{work.id}/README.txt\",\"last_modified\":\"2023-09-08T09:15:26.744-04:00\",\"size\":-1,\"checksum\":\"/HFvG2uRk/3BBDRsYqfKaA==\"" \
    ",\"work_id\":#{work.id},\"filename_display\":\"10.34770/tbd/#{work.id}/README.txt\",\"url\":\"https://dataspace.princeton.edu/bitstream/88435/dsp01bc386n47h/1\"}]"
  end
  let(:s3_file) { S3File.from_json(JSON.parse(s3_files_json).first) }
  let(:s3_aws_file) do
    file = s3_file.clone
    file.filename = file.filename_display
    file
  end
  subject(:job) { described_class.perform_later(dspace_files_json: s3_files_json, work_id: work.id, migration_snapshot_id: migration_snapshot.id) }
  let(:work) { FactoryBot.create :draft_work }
  let(:migration_snapshot) do
    MigrationUploadSnapshot.create(files: [{ "checksum" => "/HFvG2uRk/3BBDRsYqfKaA==", "filename" => "10.34770/tbd/#{work.id}/README.txt", "migrate_status" => "started" }], work: work,
                                   url: "example.com")
  end
  let(:fake_s3_service) { instance_double(S3QueryService, bucket_name: "work-bucket", prefix: "abc/123/#{work.id}/") }
  let(:etag) { "test-etag" }
  let(:work_activity_json) { { migration_id: migration_snapshot.id, message: "test migration", file_count: 1, directory_count: 0 }.to_json }
  let(:work_activity) { WorkActivity.add_work_activity(work.id, work_activity_json, work.created_by_user_id, activity_type: WorkActivity::MIGRATION_START) }
  let(:fake_dpsace_connector) { instance_double(PULDspaceConnector, download_bitstreams: [s3_file]) }
  let(:fake_aws_connector) { instance_double(PULDspaceAwsConnector, upload_to_s3: [{ key: s3_file.filename_display, file: s3_aws_file, error: nil }]) }

  before do
    allow(PULDspaceConnector).to receive(:new).and_return(fake_dpsace_connector)
    allow(PULDspaceAwsConnector).to receive(:new).and_return(fake_aws_connector)
    work_activity
    allow(Work).to receive(:find).and_return(work)
    allow(fake_s3_service).to receive(:upload_file).and_return(true)
    allow(fake_s3_service).to receive(:get_s3_object_attributes).and_return({ etag: etag })
    allow(work).to receive(:s3_query_service).and_return(fake_s3_service)
    allow(s3_aws_file).to receive(:s3_query_service).and_return(fake_s3_service)
    allow(Honeybadger).to receive(:notify)
  end

  it "runs an aws upload" do
    perform_enqueued_jobs { job }
    expect(fake_dpsace_connector).to have_received(:download_bitstreams)
    expect(fake_aws_connector).to have_received(:upload_to_s3)
    migration_snapshot.reload
    expect(migration_snapshot).to be_migration_complete
    expect(Honeybadger).not_to have_received(:notify)
  end

  context "when the file has already been migrated" do
    let(:migration_snapshot) do
      MigrationUploadSnapshot.create(files: [{ "checksum" => "/HFvG2uRk/3BBDRsYqfKaA==", "filename" => "10.34770/tbd/#{work.id}/README.txt", "migrate_status" => "complete" }], work: work,
                                     url: "example.com")
    end

    it "does not run an aws upload" do
      perform_enqueued_jobs { job }
      expect(fake_dpsace_connector).not_to have_received(:download_bitstreams)
      expect(fake_s3_service).not_to have_received(:upload_file).with(hash_including(filename: "README.txt", md5_digest: "/HFvG2uRk/3BBDRsYqfKaA==", size: 4946))
      expect(Honeybadger).not_to have_received(:notify)
    end
  end
end
