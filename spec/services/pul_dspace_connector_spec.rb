# frozen_string_literal: true
require "rails_helper"

RSpec.describe PULDspaceConnector, type: :model do
  include ActiveJob::TestHelper

  subject(:dspace_data) { described_class.new(work) }
  let(:work) { FactoryBot.create :draft_work }

  describe "#bitstreams" do
    it "finds no bitstreams" do
      expect(dspace_data.bitstreams).to be_empty
    end
  end

  describe "#download_bitstreams" do
    it "finds no bitstreams" do
      expect(dspace_data.download_bitstreams).to be_empty
    end
  end

  describe "#metdata" do
    it "finds no metdata" do
      expect(dspace_data.metadata).to eq({})
    end
  end

  describe "#doi" do
    it "finds no doi" do
      expect(dspace_data.doi).to be_empty
    end
  end
end
