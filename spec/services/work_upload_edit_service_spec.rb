# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkUploadsEditService do
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
    S3File.new(
      filename: "#{work.doi}/#{work.id}/us_covid_2019.csv",
      last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
      size: 10_759,
      checksum: "abc123",
      query_service: s3_query_service_double
    )
  end
  let(:s3_file2) do
    S3File.new(
      filename: "#{work.doi}/#{work.id}/us_covid_2020.csv",
      last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
      size: 12_739,
      checksum: "abc567",
      query_service: s3_query_service_double
    )
  end
  let(:s3_file3) do
    S3File.new(
      filename: "#{work.doi}/#{work.id}/orcid.csv",
      last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
      size: 12_739,
      checksum: "abc567",
      query_service: s3_query_service_double
    )
  end
  let(:s3_data) { [s3_file1, s3_file2] }

  # before do
  # stub_request(:put, /#{bucket_url}/).to_return(status: 200)
  # work.pre_curation_uploads.attach(uploaded_file)
  # stub_request(:delete, attachment_url).to_return(status: 200)
  # end

  context "When no uploads changes are in the params" do
    let(:params) { { "work_id" => "" }.with_indifferent_access }

    it "returns all existing files" do
      fake_s3_service = stub_s3(data: s3_data, bucket_url: bucket_url)

      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      filenames = updated_work.pre_curation_uploads_fast.map(&:filename)
      expect(filenames).to eq(s3_data.map(&:filename))
      expect(fake_s3_service).not_to have_received(:delete_s3_object)
      expect(work.work_activity.count).to be 0
    end
  end

  context "When upload additions are in the params" do
    # this is not possible at the moment, but should be
  end

  context "When upload removals are in the params" do
    let(:params) { { "work_id" => "", "deleted_uploads" => { s3_data[0].filename => "1" } }.with_indifferent_access }

    it "returns all existing files except the deleted one" do
      fake_s3_service = stub_s3(bucket_url: bucket_url)
      allow(fake_s3_service).to receive(:client_s3_files).and_return(s3_data, [s3_file2])

      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      expect(updated_work.pre_curation_uploads_fast.map(&:filename)).to eq([s3_file2.key])
      expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file1.key).once

      # it logs the delete (and no additions)
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"] == s3_data[0].filename }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" }).to be nil
    end
  end

  context "When upload replacements are in the params" do
    let(:attachment_url) { "#{bucket_url}#{work.doi}/#{work.id}/us_covid_2020.csv" }
    let(:s3_file4) do
      S3File.new(
        filename: "#{work.doi}/#{work.id}/datacite_basic.xml",
        last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
        size: 12_739,
        checksum: "abc567",
        query_service: s3_query_service_double
      )
    end

    let(:params) { { "work_id" => "", "replaced_uploads" => { work.pre_curation_uploads_fast.last.key => uploaded_file4 } }.with_indifferent_access }

    it "replaces the correct file" do
      fake_s3_service = stub_s3(bucket_url: bucket_url)
      # TODO: why do I need the first set of files twice.  Maybe a memo is not getting set properly?
      allow(fake_s3_service).to receive(:client_s3_files).and_return([s3_file1, s3_file2, s3_file3], [s3_file1, s3_file2, s3_file3], [s3_file1, s3_file3, s3_file4])
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.pre_curation_uploads_fast

      # remeber order of the files will be alphabetical
      expect(list.map(&:filename)).to eq([s3_file4.key, s3_file3.key, s3_file1.key])
      expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file2.key).once

      # it logs the activity
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"] == s3_file2.key }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" && log["filename"] == "datacite_basic.xml" }).not_to be nil
    end
  end

  context "When replacing all uploads is the params" do
    let(:params) { { "work_id" => "", "pre_curation_uploads" => [uploaded_file2, uploaded_file3] }.with_indifferent_access }

    it "replaces all the files" do
      fake_s3_service = stub_s3(bucket_url: bucket_url)
      # TODO: why do I need the first set of files twice.  Maybe a memo is not getting set properly?
      allow(fake_s3_service).to receive(:client_s3_files).and_return([s3_file1], [s3_file1], [s3_file2, s3_file3])
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.reload.pre_curation_uploads_fast
      expect(list.map(&:filename)).to eq([s3_file3.key, s3_file2.key])
      expect(fake_s3_service).to have_received(:delete_s3_object).with(s3_file1.key).once

      # it logs the activity
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"] == s3_file1.key }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" && log["filename"] == "us_covid_2020.csv" }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" && log["filename"] == "orcid.csv" }).not_to be nil
    end
  end

  context "When replacing all uploads in the params, but some overlap" do
    let(:params) { { "work_id" => "", "pre_curation_uploads" => [uploaded_file2, uploaded_file3] }.with_indifferent_access }

    it "replaces all the files" do
      fake_s3_service = stub_s3(data: s3_data, bucket_url: bucket_url)

      # upload the two new files
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      filenames = updated_work.reload.pre_curation_uploads.map { |attachment| attachment.filename.to_s }
      expect(filenames).to eq([uploaded_file2.original_filename, uploaded_file3.original_filename])

      # deleted the two existing files
      expect(fake_s3_service).to have_received(:delete_s3_object).twice

      # it logs the activity (2 deletes + 2 adds)
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"].include?("us_covid_2019.csv") }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "deleted" && log["filename"].include?("us_covid_2020.csv") }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" && log["filename"].include?("us_covid_2020.csv") }).not_to be nil
      expect(activity_log.find { |log| log["action"] == "added" && log["filename"].include?("orcid.csv") }).not_to be nil
    end
  end
end
