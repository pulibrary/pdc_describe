# frozen_string_literal: true
require "rails_helper"

RSpec.describe Collection, type: :model do
  it "creates default collections only when needed" do
    described_class.delete_all
    expect(described_class.count).to be 0

    described_class.create_defaults
    default_count = described_class.count
    expect(default_count).to be > 0

    expect(Collection.where(code: "PPPL").count).to be 1
    expect(Collection.where(code: "RD").count).to be 1
    expect(Collection.where(code: "ETD").count).to be 1
    expect(Collection.where(code: "LIB").count).to be 1

    described_class.create_defaults
    expect(described_class.count).to be default_count
  end

  it "creates defaults when not defined" do
    described_class.delete_all
    expect(described_class.count).to be 0
    expect(Collection.default).to_not be nil

    described_class.delete_all
    expect(described_class.count).to be 0
    expect(Collection.default_for_department("41000")).to_not be nil
  end
end
