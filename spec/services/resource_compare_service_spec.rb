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
    work2 .resource.description = "hello"
    compare = described_class.new(work1.resource, work2.resource)
    expect(compare.identical?).to be false
    expect(compare.differences[:description].first[:action]).to be :changed
    expect(compare.differences[:description].first[:to]).to be "hello"
  end

  it "detects changes in multi-value properties" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    work2.resource.keywords = ["a", "b"]
    compare = described_class.new(work1.resource, work2.resource)
    differences = compare.differences[:keywords]
    expect(differences).to eq [{:action=>:changed, :from=>"", :to=>"a\nb"}]

    work3 = FactoryBot.create(:shakespeare_and_company_work)
    work3.resource.keywords = ["b", "c"]
    compare = described_class.new(work2.resource, work3.resource)
    differences = compare.differences[:keywords]
    expect(differences).to eq [{:action=>:changed, :from=>"a\nb", :to=>"b\nc"}]
  end

  it "detects changes in creators" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    creator_other = PDCMetadata::Creator.new_person("Robert", "Smith", nil, 2)
    work2.resource.creators = [work1.resource.creators.first, creator_other]

    compare = described_class.new(work1.resource, work2.resource)
    differences = compare.differences[:creators]
    expect(differences).to eq [{:action=>:changed,
         :from=>"Kotin, Joshua | 1 | ",
         :to=>"Kotin, Joshua | 1 | \nSmith, Robert | 2 | "}]

    work3 = FactoryBot.create(:shakespeare_and_company_work)
    work3.resource.creators = [creator_other]
    compare = described_class.new(work2.resource, work3.resource)
    differences = compare.differences[:creators]
    expect(differences).to eq [{:action=>:changed,
        :from=>"Kotin, Joshua | 1 | \nSmith, Robert | 2 | ",
        :to=>"Smith, Robert | 2 | "}]
  end
end
