# frozen_string_literal: true
require "rails_helper"

RSpec.describe Ark, type: :model, mock_ezid_api: true do
  describe ".mint" do
    # Please see spec/support/ezid_specs.rb
    let(:ezid) { @ezid }

    it "mints a new EZID" do
      expect(described_class.mint).to eq(ezid)
    end
  end

  describe ".update" do
    let(:ark) { "ark:/88435/dsp01qb98mj541" }
    let(:old_target) { "https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541" }
    let(:new_target) { "https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541-new" }

    it "makes the call to EZID" do
      described_class.update(ark, new_target)
      expect(@identifier).to have_received(:save!)
    end

    it "does not make the call to EZID" do
      described_class.update(ark, old_target)
      expect(@identifier).to_not have_received(:save!)
    end
  end

  describe ".valid?" do
    let(:id) { "id" }

    context "when the ARK references a non-existent EZID" do
      before do
        allow(Ezid::Identifier).to receive(:find).and_raise(Net::HTTPServerException, '400 "Bad Request"')
      end

      it "returns false" do
        expect(described_class.valid?(id)).to be false
      end
    end

    context "when the ARK references an existing EZID" do
      let(:identifier) { @identifier }

      it "returns true" do
        expect(described_class.valid?(id)).to be true
      end
    end
  end
end
