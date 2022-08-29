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

  describe ".default_for_department" do
    subject(:collection) { described_class.default_for_department(department_number) }

    context "when the department number is less than 31000" do
      let(:department_number) { "30000" }
      it "provides the default collection" do
        expect(collection).to be_a(Collection)
        expect(collection.code).to eq("RD")
      end
    end

    context "when the department number is unexpected" do
      let(:department_number) { "foobar" }
      it "provides the default collection" do
        expect(collection).to be_a(Collection)
        expect(collection.code).to eq("RD")
      end
    end

    context "when the department number is PPPL" do
      let(:department_number) { "31000" }
      it "provides the default collection" do
        expect(collection).to be_a(Collection)
        expect(collection.code).to eq("PPPL")
      end
    end
  end
end
