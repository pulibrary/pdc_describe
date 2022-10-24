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

  before do
    stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    work.pre_curation_uploads.attach(uploaded_file)
    stub_request(:delete, attachment_url).to_return(status: 200)
  end

  context "When no uploads changes are in the params" do
    let(:params) { { "work_id" => "" }.with_indifferent_access }

    it "returns all existing files" do
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.pre_curation_uploads
      expect(list.map(&:filename)).to eq([uploaded_file.original_filename])
      expect(a_request(:delete, attachment_url)).not_to have_been_made
      expect(work.work_activity.count).to be 0
    end
  end

  context "When upload additions are in the params" do
    # this is not possible at the moment, but should be
  end

  context "When upload removals are in the params" do
    let(:params) { { "work_id" => "", "deleted_uploads" => { "10.34770/123-abc/#{work.id}/#{uploaded_file.original_filename}" => "1" } }.with_indifferent_access }

    before do
      work.pre_curation_uploads.attach(uploaded_file2)
    end

    it "returns all existing files except the deleted one" do
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.pre_curation_uploads
      expect(list.map(&:filename)).to eq([uploaded_file2.original_filename])
      expect(a_request(:delete, attachment_url)).to have_been_made.once
      # it logs the delete
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find {|log| log["action"] == "deleted" && log["filename"]== "us_covid_2019.csv"}).not_to be nil
    end
  end

  context "When upload replacements are in the params" do
    let(:attachment_url) { "#{bucket_url}#{work.doi}/#{work.id}/us_covid_2020.csv" }
    before do
      work.pre_curation_uploads.attach(uploaded_file2)
      work.pre_curation_uploads.attach(uploaded_file3)
    end
    let(:params) { { "work_id" => "", "replaced_uploads" => { "1" => uploaded_file4 } }.with_indifferent_access }

    it "replaces the correct file" do
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.pre_curation_uploads

      # remeber order of the files will be alphabetical
      expect(list.map(&:filename)).to eq([uploaded_file.original_filename, uploaded_file3.original_filename, uploaded_file4.original_filename])
      expect(a_request(:delete, attachment_url)).to have_been_made.once

      # it logs the activity
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find {|log| log["action"] == "deleted" && log["filename"]== "us_covid_2020.csv"}).not_to be nil
      expect(activity_log.find {|log| log["action"] == "added" && log["filename"]== "datacite_basic.xml"}).not_to be nil
    end
  end

  context "When replacing all uploads is the params" do
    let(:params) { { "work_id" => "", "pre_curation_uploads" => [uploaded_file2, uploaded_file3] }.with_indifferent_access }

    it "replaces all the files" do
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.reload.pre_curation_uploads
      expect(list.map(&:filename)).to eq([uploaded_file2.original_filename, uploaded_file3.original_filename])
      expect(a_request(:delete, attachment_url)).to have_been_made.once

      # it logs the activity
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find {|log| log["action"] == "deleted" && log["filename"]== "us_covid_2019.csv"}).not_to be nil
      expect(activity_log.find {|log| log["action"] == "added" && log["filename"]== "us_covid_2020.csv"}).not_to be nil
      expect(activity_log.find {|log| log["action"] == "added" && log["filename"]== "orcid.csv"}).not_to be nil
    end
  end

  context "When replacing all uploads is the params, but some overlap" do
    let(:params) { { "work_id" => "", "pre_curation_uploads" => [uploaded_file, uploaded_file3] }.with_indifferent_access }

    it "replaces all the files" do
      upload_service = described_class.new(work, user)
      updated_work = upload_service.update_precurated_file_list(params)
      list = updated_work.pre_curation_uploads
      expect(list.map(&:filename)).to eq([uploaded_file.original_filename, uploaded_file3.original_filename])

      # we delete all items and start over because even if the filename matches we want the new version of the file they just uploaded
      expect(a_request(:delete, attachment_url)).to have_been_made.once

      # it logs the activity
      activity_log = JSON.parse(work.work_activity.first.message)
      expect(activity_log.find {|log| log["action"] == "deleted" && log["filename"]== "us_covid_2019.csv"}).not_to be nil
      expect(activity_log.find {|log| log["action"] == "added" && log["filename"]== "us_covid_2019.csv"}).not_to be nil
      expect(activity_log.find {|log| log["action"] == "added" && log["filename"]== "orcid.csv"}).not_to be nil
    end
  end
end
