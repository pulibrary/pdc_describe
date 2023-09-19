# frozen_string_literal: true
require "rails_helper"

RSpec.describe FileRenameMappingService do
  let(:upload_snapshot) { FactoryBot.build(:upload_snapshot_with_illegal_characters) }
  let(:subject) { described_class.new(upload_snapshot: upload_snapshot) }

  it "has an upload snapshot" do
    expect(subject.upload_snapshot).to eq upload_snapshot
  end

  it "has an array of FileRenameService objects" do
    expect(subject.files.count).to eq 4
    expect(subject.files.first).to be_instance_of FileRenameService
  end

  it "has a list of original filenames" do
    original_filenames = [
      "10.34770/tbd/4/laser width.xlsx",
      "10.34770/tbd/4/all OH LIF decays.xlsx",
      "10.34770/tbd/4/Dry He 2mm 10kV le=0.8mJ RH 50%.csv",
      "10.34770/tbd/4/Dry He 2mm 20kV le=0.8mJ RH 50%.csv"
    ]
    expect(subject.original_filenames).to eq original_filenames
  end

  it "knows whether it needs to rename any files" do
    expect(subject.rename_needed?).to eq true
  end

  it "produces a mapping of all the file renaming" do
    expect(subject.renaming_document).to match(/Some files have been renamed/)
  end
end
