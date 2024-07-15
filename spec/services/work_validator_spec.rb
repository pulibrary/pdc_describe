# frozen_string_literal: true
require "rails_helper"

RSpec.describe Work, type: :model do
  describe "#valid_to_draft" do
    let(:work) { FactoryBot.build(:draft_work, ark: "ark:/88435/dsp01zc77st047") }
    before do
      allow(Ark).to receive(:valid?).and_return(true)
    end

    it "validates the ark" do
      work.save
      expect(Ark).to have_received(:valid?).once
    end

    context "when the ark does not change" do
      before do
        work.save
      end
      it "does not validate the ark" do
        expect(work.save).to be_truthy
        expect(Ark).to have_received(:valid?).once
      end
    end

    context "when the ark changes" do
      before do
        work.save
        work.resource.ark = "ark:/88435/changed999"
      end
      it "validates the ark" do
        expect(work.save).to be_truthy
        expect(Ark).to have_received(:valid?).twice
      end
    end

    context "when the ark is not set" do
      let(:work) { FactoryBot.build(:draft_work) }

      it "does not validate the ark" do
        expect(work.save).to be_truthy
        expect(Ark).not_to have_received(:valid?)
      end
    end
  end

  context "datacite xml is invalid" do
    let(:work) do
      stub_s3 data: [FactoryBot.build(:s3_readme)]
      work = FactoryBot.create :draft_work
      work.resource.individual_contributors = [PDCMetadata::Creator.new_individual_contributor("Sally", "Smith", "", "", 0)]
      work.save
      work
    end

    it "is not valid" do
      validator = WorkValidator.new(work)
      expect(validator.valid?).to be_truthy # we can still save, we just can not transition to submitted
      expect(validator.valid_to_submit).to be_falsey
      expect(work.errors.full_messages).to eq(["Contributor: Type cannot be nil"])
    end
  end

  describe "#valid_to_complete" do
    let(:work) { FactoryBot.create :draft_work }

    it "is not valid" do
      stub_s3
      validator = WorkValidator.new(work)
      expect(validator.valid?).to be_truthy # we can still save, we just can not transition to awaiting approval
      expect(validator.valid_to_complete).to be_falsey
      expect(work.errors.full_messages).not_to be_empty
      full_message = work.errors.full_messages[0]
      expect(full_message).to eq("You must include a README. <a href='/works/#{work.id}/readme-select'>Please upload one</a>")
    end

    context "a migrated work" do
      it "is valid" do
        work.resource.migrated = true
        stub_s3
        validator = WorkValidator.new(work)
        expect(validator.valid?).to be_truthy # we can still save, we just can not transition to awaiting approval
        expect(validator.valid_to_complete).to be_truthy
        expect(work.errors.full_messages).to eq([])
      end
    end

    context "a readme exists" do
      let(:s3_readme) {FactoryBot.build(:s3_readme)}
      let(:s3_file) {FactoryBot.build(:s3_file)}
      before do
        stub_s3 data: [s3_readme, s3_file]
      end

      it "is valid" do
        validator = WorkValidator.new(work)

        expect(validator.valid?).to be_truthy
        expect(validator.valid_to_complete).to be_truthy
        expect(work.errors.full_messages).to eq([])
      end
    end
  end

  describe "#valid_to_submit" do
    let(:work) { FactoryBot.create :draft_work }

    it "is valid" do
      stub_s3
      validator = WorkValidator.new(work)
      expect(validator.valid?).to be_truthy
      expect(validator.valid_to_submit).to be_truthy
      expect(work.errors.full_messages).to eq([])
    end
  end
end
