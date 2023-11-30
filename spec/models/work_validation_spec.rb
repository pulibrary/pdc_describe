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
end
