# frozen_string_literal: true
require "rails_helper"

RSpec.describe Collection, type: :model do
  it "creates default collections only when needed" do
    described_class.delete_all
    expect(described_class.count).to be 0

    described_class.create_defaults
    default_count = described_class.count
    expect(default_count).to be > 0

    described_class.create_defaults
    expect(described_class.count).to be default_count
  end
end
