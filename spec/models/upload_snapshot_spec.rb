# frozen_string_literal: true
require "rails_helper"

RSpec.describe UploadSnapshot, type: :model do
  subject(:upload_snapshot) { described_class.new(uri: uri, work: work) }

  let(:uri) { "https://localhost/snapshot.bin" }
  let(:work) { FactoryBot.create(:approved_work) }

  describe "#uri" do
    it "accesses the URI field" do
      expect(upload_snapshot.uri).to eq(uri)
    end
  end

  describe "#work" do
    it "accesses the Work for which this is a snapshot" do
      expect(upload_snapshot.work).to eq(work)
    end
  end
end
