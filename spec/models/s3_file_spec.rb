# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3File, type: :model do
  let(:subject) { described_class.new(filename: filename) }
  let(:filename) { "research_data.csv" }

  it "can take a filename as an initial argument" do
    expect(subject.filename).to eq filename
  end
end
