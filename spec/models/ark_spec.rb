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

    before do
      allow(@identifier).to receive(:save)
    end

    it "makes the call to EZID when the target is changing" do
      described_class.update(ark, new_target)
      expect(@identifier).to have_received(:save)
    end

    it "does not make the call to EZID when the target is not changing" do
      described_class.update(ark, old_target)
      expect(@identifier).to_not have_received(:save)
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

    context "consistently formatting ark for EZID query" do
      let(:stripped_down_ark) { "88435/dsp015999n653h" }
      let(:formatted_ark) { "ark:/#{stripped_down_ark}" }

      it "gets reformatted when needed" do
        expect(described_class.format_ark(stripped_down_ark)).to eq formatted_ark
      end

      it "does not reformat a correctly formatted ark" do
        expect(described_class.format_ark(formatted_ark)).to eq formatted_ark
      end
    end

    context "when the ARK references an existing EZID" do
      let(:identifier) { @identifier }

      it "returns true" do
        expect(described_class.valid?(id)).to be true
      end
    end
  end

  describe "#object" do
    let(:ezid) { "ark:/88435/dsp01qb98mj541" }
    let(:ark) do
      described_class.new(ezid)
    end

    it "accesses the EZID identifier object" do
      resolved = ark.object
      expect(resolved).to eq(@identifier)
    end
  end

  describe "#target" do
    let(:ezid) { "ark:/88435/dsp01qb98mj541" }
    let(:ark) do
      described_class.new(ezid)
    end

    it "accesses the EZID identifier object" do
      resolved = ark.target
      expect(resolved).to eq("https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541")
    end
  end

  describe "#target=" do
    let(:ezid) { "ark:/88435/dsp01qb98mj541" }
    let(:ark) do
      described_class.new(ezid)
    end

    it "accesses the EZID identifier object" do
      resolved = ark.target
      expect(resolved).to eq("https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541")

      ark.target = "https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541-new"

      resolved = ark.target
      expect(resolved).to eq("https://dataspace.princeton.edu/handle/88435/dsp01qb98mj541-new")
    end
  end

  describe "#save!" do
    let(:ezid) { "ark:/88435/dsp01qb98mj541" }
    let(:ark) do
      described_class.new(ezid)
    end

    it "accesses the EZID identifier object" do
      ark.save!

      expect(@identifier).to have_received(:modify)
    end
  end
end
