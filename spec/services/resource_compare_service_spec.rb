# frozen_string_literal: true
require "rails_helper"

describe ResourceCompareService do
  it "detects identical objects" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    compare = described_class.new(work1.resource, work2.resource)
    expect(compare.identical?).to be true
  end

  it "detects simple changes" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    work2 .resource.description = "All data related to Shakespeare and Company bookshop"
    compare = described_class.new(work1.resource, work2.resource)
    expect(compare.identical?).to be false
    expect(compare.differences[:description].first[:action]).to be :diff
    expect(compare.differences[:description].first[:diff]).to eq [
      { action: "=", new: "All data ", old: "All data " },
      { action: "-", new: "", old: "is " },
      { action: "=", new: "related to ", old: "related to " },
      { action: "-", new: "", old: "the " },
      { action: "=",
        new: "Shakespeare and Company bookshop",
        old: "Shakespeare and Company bookshop" },
      { action: "-",
        new: "",
        old: " and lending library opened and operated by Sylvia Beach in Paris, 1919–1962." }
    ]
  end

  it "detects changes in multi-value properties" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    work2.resource.keywords = ["a", "b"]
    compare = described_class.new(work1.resource, work2.resource)
    differences = compare.differences[:keywords]
    expect(differences.find { |diff| diff[:action] == :added && diff[:value] == "a" }).not_to be nil
    expect(differences.find { |diff| diff[:action] == :added && diff[:value] == "b" }).not_to be nil
    expect(differences.find { |diff| diff[:action] == :added && diff[:value] == "d" }).to be nil

    work3 = FactoryBot.create(:shakespeare_and_company_work)
    work3.resource.keywords = ["b", "c"]
    compare = described_class.new(work2.resource, work3.resource)
    differences = compare.differences[:keywords]
    expect(differences.find { |diff| diff[:action] == :removed && diff[:value] == "a" }).not_to be nil
    expect(differences.find { |diff| diff[:action] == :added && diff[:value] == "c" }).not_to be nil
    expect(differences.find { |diff| diff[:value] == "b" }).to be nil
  end

  it "detects changes in creators" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    creator_other = PDCMetadata::Creator.new_person("Robert", "Smith", nil, 2)
    work2.resource.creators = [work1.resource.creators.first, creator_other]

    compare = described_class.new(work1.resource, work2.resource)
    differences = compare.differences[:creators]
    expect(differences.find { |diff| diff[:action] == :added && diff[:value] == "Smith, Robert | 2 | " }).not_to be nil

    work3 = FactoryBot.create(:shakespeare_and_company_work)
    work3.resource.creators = [creator_other]
    compare = described_class.new(work2.resource, work3.resource)
    differences = compare.differences[:creators]
    expect(differences.find { |diff| diff[:action] == :removed && diff[:value] == "Kotin, Joshua | 1 | " }).not_to be nil
  end
end
