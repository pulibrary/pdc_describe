# frozen_string_literal: true

require "rails_helper"

RSpec.describe "View status of data in S3" do
  let(:identifier) { double(Ezid::Identifier) }
  let(:ezid_metadata_values) do
    {
      "_updated" => "1611860047",
      "_target" => "http://arks.princeton.edu/ark:/88435/dsp01zc77st047",
      "_profile" => "erc",
      "_export" => "yes",
      "_owner" => "pudiglib",
      "_ownergroup" => "pudiglib",
      "_created" => "1611860047",
      "_status" => "public"
    }
  end
  let(:ezid_metadata) do
    Ezid::Metadata.new(ezid_metadata_values)
  end
  let(:ezid) { "ark:/88435/dsp01zc77st047" }

  before do
    # this is a work-around due to an issue with webmock
    allow(Ezid::Identifier).to receive(:find).and_return(identifier)

    allow(identifier).to receive(:metadata).and_return(ezid_metadata)
    allow(identifier).to receive(:id).and_return(ezid)
    allow(identifier).to receive(:modify)

    sign_in user
  end

  describe "when a dataset has a DOI and its data is in S3" do
    let(:user) { FactoryBot.create :user }
    let(:dataset) { FactoryBot.create :shakespeare_and_company_dataset }
    let(:s3_query_service_double) { instance_double(S3QueryService) }
    let(:file1) do
      S3File.new(
        filename: "SCoData_combined_v1_2020-07_README.txt",
        last_modified: Time.parse("2022-04-21T18:29:40.000Z"),
        size: 10_759
      )
    end
    let(:file2) do
      S3File.new(
        filename: "SCoData_combined_v1_2020-07_datapackage.json",
        last_modified: Time.parse("2022-04-21T18:30:07.000Z"),
        size: 12_739
      )
    end
    let(:s3_data) { [file1, file2] }

    before do
      allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
      allow(s3_query_service_double).to receive(:data_profile).and_return(s3_data)
    end

    it "shows data from S3", js: true do
      visit dataset_path(dataset)
      expect(page).to have_content dataset.title

      expect(page).to have_content file1.filename
      expect(page).to have_content file1.last_modified
      expect(page).to have_content "10.5 KB"

      expect(page).to have_content file2.filename
      expect(page).to have_content file2.last_modified
      expect(page).to have_content "12.4 KB"
    end
  end
end
