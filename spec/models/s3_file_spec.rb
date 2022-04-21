# frozen_string_literal: true
require "rails_helper"

RSpec.describe S3File, type: :model do
  let(:subject) { described_class.new }

  it "has a filename" do
    subject.filename = "my_filename"
    expect(subject.filename).to eq "my_filename"
  end
end
