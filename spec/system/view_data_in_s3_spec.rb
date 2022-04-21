# frozen_string_literal: true

require "rails_helper"

RSpec.describe "View status of data in S3" do
  before { sign_in user }

  describe "when a dataset has a DOI and its data is in S3" do
    let(:user) { FactoryBot.create :user }
    let(:dataset) { FactoryBot.create :shakespeare_and_company_dataset }

    it "shows data from S3", js: true do
      visit dataset_path(dataset)
      expect(page).to have_content dataset.title
    end
  end
end
