# frozen_string_literal: true

require "rails_helper"

RSpec.describe "View status of data in S3" do
  before { sign_in user }

  describe "when a dataset has a DOI and its data is in S3" do
    let(:user) { FactoryBot.create :user }
    let(:dataset) { FactoryBot.create :shakespeare_and_company_dataset }
    let(:s3_query_service_double) { instance_double(S3QueryService) }
    let(:file1) { S3File.new(filename: "SCoData_combined_v1_2020-07_README.txt") }
    let(:file2) { S3File.new(filename: "SCoData_combined_v1_2020-07_datapackage.json") }
    let(:s3_data) { [file1, file2] }

    before do
      allow(S3QueryService).to receive(:new).and_return(s3_query_service_double)
      allow(s3_query_service_double).to receive(:data_profile).and_return(s3_data)
    end

    it "shows data from S3", js: true do
      visit dataset_path(dataset)
      expect(page).to have_content dataset.title
      expect(page).to have_content file1.filename
      expect(page).to have_content file2.filename
    end
  end
end
