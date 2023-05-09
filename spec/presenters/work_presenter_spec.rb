# frozen_string_literal: true
require "rails_helper"

RSpec.describe WorkPresenter do
  subject(:work_presenter) { described_class.new(work: work) }

  let(:description) { "This tests the link http://library.princeton.edu. It also has a summary." }
  let(:resource) { FactoryBot.build(:resource, doi: "10.34770/123-abc", description: description) }
  let(:work) { FactoryBot.create(:draft_work, resource: resource) }

  describe "#description" do
    it "autolinks URLs within the description metadata" do
      expect(work_presenter.description).not_to eq(work.resource.description)
      expect(work_presenter.description).to eq("This tests the link <a href=\"http://library.princeton.edu\" target=\"_blank\">http://library.princeton.edu</a>. It also has a summary.")
    end
  end
end
