# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkUploadsEditService do
  include ActiveJob::TestHelper
  let(:user) { FactoryBot.create :research_data_moderator }
  let(:work) { FactoryBot.create :draft_work }
  let(:uploaded_file) do
    fixture_file_upload("us_covid_2019.csv", "text/csv")
  end
  let(:uploaded_file2) do
    fixture_file_upload("us_covid_2020.csv", "text/csv")
  end
  let(:uploaded_file3) do
    fixture_file_upload("orcid.csv", "text/csv")
  end
  let(:uploaded_file4) do
    fixture_file_upload("datacite_basic.xml", "text/xml")
  end

  let(:bucket_url) do
    "https://example-bucket.s3.amazonaws.com/"
  end

  let(:attachment_url) { "#{bucket_url}#{work.doi}/#{work.id}/us_covid_2019.csv" }

  let(:s3_query_service_double) { instance_double(S3QueryService) }
  let(:s3_file1) do
    FactoryBot.build(:s3_file, work: work,
                               filename: "#{work.doi}/#{work.id}/us_covid_2019.csv",
                               last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
                               size: 10_759,
                               checksum: "abc123")
  end
  let(:s3_file2) do
    FactoryBot.build(:s3_file, work: work,
                               filename: "#{work.doi}/#{work.id}/us_covid_2020.csv",
                               last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
                               size: 12_739,
                               checksum: "abc567")
  end
  let(:s3_file3) do
    FactoryBot.build(:s3_file, work: work,
                               filename: "#{work.doi}/#{work.id}/orcid.csv",
                               last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
                               size: 12_739,
                               checksum: "abc567")
  end
  let(:s3_data) { [s3_file1, s3_file2] }

  before do
    stub_request(:get, /#{Regexp.escape("https://example-bucket.s3.amazonaws.com/us_covid")}.+\.csv/).to_return(status: 200, body: "", headers: {})
    stub_request(:get, /#{Regexp.escape("https://example-bucket.s3.amazonaws.com/orcid")}*+\.csv/).to_return(status: 200, body: "", headers: {})
  end

  context "When no uploads changes are requested" do
    let(:added_files) { [] }
    let(:deleted_files) { [] }

    it "returns all existing files" do
      fake_s3_service = stub_s3(data: s3_data, bucket_url: bucket_url)

      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(added_files, deleted_files)
      filenames = updated_work.pre_curation_uploads_fast.map(&:filename)
      expect(filenames).to eq(s3_data.map(&:filename))
      expect(fake_s3_service).not_to have_received(:delete_s3_object)
      expect(work.work_activity.count).to be 0
    end
  end

  context "When upload additions are in the params" do
    let(:added_files) { [uploaded_file3] }
    let(:deleted_files) { [] }

    it "returns all existing files plus the new one" do
      s3_query_service = mock_s3_query_service_class(data: [s3_file1, s3_file2])
      allow(s3_query_service).to receive(:delete_s3_object)

      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(added_files, deleted_files)

      expect(updated_work.pre_curation_uploads_fast.map(&:filename).sort).to eq([s3_file1.key, s3_file2.key].sort)
      expect(s3_query_service).not_to have_received(:delete_s3_object)

      expect(AttachFileToWorkJob).to have_received(:perform_later).with(hash_including(file_name: "orcid.csv", size: 287, user_id: user.id, work_id: work.id))

      # it logs the addition (and no delete)
      # activity_log = JSON.parse(updated_work.work_activity.first.message)
      # expect(activity_log.find { |log| log["action"] == "added" && log["filename"] == s3_file3.filename_display }).not_to be nil
      # expect(activity_log.find { |log| log["action"] == "deleted" }).to be nil
    end
  end

  context "When upload removals are requested" do
    let(:added_files) { [] }
    let(:deleted_files) { [s3_data[0].filename] }

    it "returns all existing files except the deleted one" do
      fake_s3_service = stub_s3(bucket_url: bucket_url)
      allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_data, [s3_file2])

      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(added_files, deleted_files)
      expect(updated_work.pre_curation_uploads_fast.map(&:filename)).to eq([s3_file2.key])
      expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file1.key).once

      # it logs the delete (and no additions)
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"] == s3_data[0].filename }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" }).to be nil
    end
  end

  context "When replacing all uploads is the params" do
    let(:added_files) { [uploaded_file2, uploaded_file3] }
    let(:deleted_files) { [s3_file1.key] }

    it "replaces all the files" do
      s3_query_service = mock_s3_query_service_class
      allow(s3_query_service).to receive(:client_s3_files).and_return([s3_file1], [s3_file2, s3_file3])
      allow(s3_query_service).to receive(:delete_s3_object)

      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(added_files, deleted_files)
      list = updated_work.reload.pre_curation_uploads_fast

      expect(list.map(&:filename)).to eq([s3_file3.key, s3_file2.key])
      expect(s3_query_service).to have_received(:delete_s3_object).with(s3_file1.key).once

      expect(AttachFileToWorkJob).to have_received(:perform_later).with(hash_including({
                                                                                         file_name: "us_covid_2020.csv",
                                                                                         size: 114,
                                                                                         user_id: user.id,
                                                                                         work_id: work.id
                                                                                       }))
      expect(AttachFileToWorkJob).to have_received(:perform_later).with(hash_including({
                                                                                         file_name: "orcid.csv",
                                                                                         size: 287,
                                                                                         user_id: user.id,
                                                                                         work_id: work.id
                                                                                       }))
    end
  end

  context "When replacing all uploads in the params, but some overlap" do
    let(:added_files) { [uploaded_file2, uploaded_file3] }
    let(:deleted_files) { [s3_file1.key, s3_file2.key] }

    it "replaces all the files" do
      s3_query_service = mock_s3_query_service_class
      allow(s3_query_service).to receive(:upload_file)
      allow(s3_query_service).to receive(:delete_s3_object)

      # upload the two new files
      upload_service = described_class.new(work, user)
      upload_service.update_precurated_file_list(added_files, deleted_files)
      expect(AttachFileToWorkJob).to have_received(:perform_later).with(hash_including({
                                                                                         file_name: "us_covid_2020.csv",
                                                                                         size: 114,
                                                                                         user_id: user.id,
                                                                                         work_id: work.id
                                                                                       }))

      expect(AttachFileToWorkJob).to have_received(:perform_later).with(hash_including({
                                                                                         file_name: "orcid.csv",
                                                                                         size: 287,
                                                                                         user_id: user.id,
                                                                                         work_id: work.id
                                                                                       }))

      # deleted the two existing files
      expect(s3_query_service).to have_received(:delete_s3_object).twice

      # it logs the activity (2 deletes + 2 adds)
      # work_activities = updated_work.work_activity
      # activity_log = work_activities.map { |work_activity| JSON.parse(work_activity.message) }.flatten
      # expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"].include?("us_covid_2019.csv") }).not_to be nil
      # expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"].include?("us_covid_2020.csv") }).not_to be nil
      # expect(activity_log.find { |log| log["action"] == "added" && log["filename"].include?("us_covid_2020.csv") }).not_to be nil
      # expect(activity_log.find { |log| log["action"] == "added" && log["filename"].include?("orcid.csv") }).not_to be nil
    end
  end
end
