# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkUploadsEditService do
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

  let(:bucket_url) do
    "https://example-bucket.s3.amazonaws.com/"
  end

  before do
    stub_request(:put, /#{bucket_url}/).to_return(status: 200)
    work.pre_curation_uploads.attach(uploaded_file)
  end

  context "When no uploads changes are in the params" do
    let(:params) { { "work_id" => "" }.with_indifferent_access }

    it "returns all existing files" do
      list = described_class.precurated_file_list(work, params)
      expect(list.map(&:filename)).to eq([uploaded_file.original_filename])
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
      list = described_class.precurated_file_list(work, params)
      expect(list.map(&:filename)).to eq([uploaded_file2.original_filename])
    end
  end

  context "When upload replacements are in the params" do
    before do
      work.pre_curation_uploads.attach(uploaded_file2)
    end
    let(:params) { { "work_id" => "", "replaced_uploads" => { "0" => uploaded_file3 } }.with_indifferent_access }

    it "replaces the correct file" do
      list = described_class.precurated_file_list(work, params)
      expect(list.first).to eq(uploaded_file3)
      expect(list.last.filename).to eq(uploaded_file2.original_filename)
    end
  end

  context "When replacing all uploads is the params" do
    let(:params) { { "work_id" => "", "pre_curation_uploads" => [uploaded_file2, uploaded_file3] }.with_indifferent_access }

    it "replaces all the files" do
      list = described_class.precurated_file_list(work, params)
      expect(list).to eq([uploaded_file2, uploaded_file3])
    end
  end
end
