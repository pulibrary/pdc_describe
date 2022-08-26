# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3File, type: :model do
  let(:subject) { described_class.new(filename: filename, last_modified: last_modified, size: size, checksum: checksum) }
  let(:filename) { "10-34770/pe9w-x904/SCoData_combined_v1_2020-07_README.txt" }
  let(:last_modified) { Time.parse("2022-04-21T18:29:40.000Z") }
  let(:size) { 10_759 }
  let(:checksum) { "abc123" }

  it "can take S3 file data at creation time" do
    expect(subject.filename).to eq filename
    expect(subject.last_modified).to eq last_modified
    expect(subject.size).to eq size
    expect(subject.checksum).to eq checksum
  end

  context "checksum with quotes" do
    let(:checksum) { "\"abc123\"" }
    it "removes the quotes in the checksum" do
      expect(subject.checksum).to eq "abc123"
    end
  end
end
