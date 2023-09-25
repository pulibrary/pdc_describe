# frozen_string_literal: true
require "rails_helper"

RSpec.describe FileRenameService do
  include ActiveJob::TestHelper

  it "has a list of illegal characters" do
    expect(FileRenameService::ILLEGAL_CHARACTERS).to be_instance_of Array
  end

  context "a file with S3 illegal characters" do
    let(:filename) { "10.80021/4dy5-dh78/473/Dry He 2mm 10kV le=0.8mJ RH 50%.csv" }
    let(:subject) { described_class.new(filename: filename) }

    it "knows the original filename" do
      expect(subject.original_filename).to eq filename
    end

    it "knows the file needs renaming" do
      expect(subject.needs_rename?).to eq true
    end

    it "knows the new filename" do
      expect(subject.new_filename(2)).to eq "10.80021/4dy5-dh78/473/Dry He 2mm 10kV le_0.8mJ RH 50_(2).csv"
    end
  end

  context "a file without S3 illegal characters" do
    let(:filename) { "a_totally_legal_filename.csv" }
    let(:subject) { described_class.new(filename: filename) }

    it "knows the file doesn't need renaming" do
      expect(subject.needs_rename?).to eq false
    end
  end
end
