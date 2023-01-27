# frozen_string_literal: true
require "rails_helper"
require "ostruct"

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
    expect(differences).to eq [{ action: :changed, from: "", to: "a\nb" }]

    work3 = FactoryBot.create(:shakespeare_and_company_work)
    work3.resource.keywords = ["b", "c"]
    compare = described_class.new(work2.resource, work3.resource)
    differences = compare.differences[:keywords]
    expect(differences).to eq [{ action: :changed, from: "a\nb", to: "b\nc" }]
  end

  it "detects changes in creators" do
    work1 = FactoryBot.create(:shakespeare_and_company_work)
    work2 = FactoryBot.create(:shakespeare_and_company_work)
    creator_other = PDCMetadata::Creator.new_person("Robert", "Smith", nil, 2)
    work2.resource.creators = [work1.resource.creators.first, creator_other]

    compare = described_class.new(work1.resource, work2.resource)
    differences = compare.differences[:creators]
    expect(differences).to eq [{ action: :changed,
                                 from: "Kotin, Joshua | 1 | ",
                                 to: "Kotin, Joshua | 1 | \nSmith, Robert | 2 | " }]

    work3 = FactoryBot.create(:shakespeare_and_company_work)
    work3.resource.creators = [creator_other]
    compare = described_class.new(work2.resource, work3.resource)
    differences = compare.differences[:creators]
    expect(differences).to eq [{ action: :changed,
                                 from: "Kotin, Joshua | 1 | \nSmith, Robert | 2 | ",
                                 to: "Smith, Robert | 2 | " }]
  end

  describe "checking every field" do
    new_values = {
      # These could be filled in with representative values, but since this
      # really just checking the coverage of the ResouceCompareService,
      # that isn't critical.
      related_objects: [],
      titles: [PDCMetadata::Title.new(title: "new title")],
      description: "new description",
      collection_tags: ["fake"],
      funders: [],
      keywords: [],
      contributors: [],
      creators: [],
      domains: ["Humanities"]
    }
    expected_diff = {
      doi: [{ action: :changed, from: "10.34770/pe9w-x904", to: "" }],
      ark: [{ action: :changed, from: "ark:/88435/dsp01zc77st047", to: "" }],
      description: [{ action: :changed,
                      from: "All data is related to the Shakespeare and Company bookshop and lending library opened and operated by Sylvia Beach in Paris, 1919–1962.",
                      to: "new description" }],
      publication_year: [{ action: :changed, from: "2020", to: "" }],
      version_number: [{ action: :changed, from: "1", to: "" }],
      publisher: [{ action: :changed, from: "Princeton University", to: "" }],
      resource_type: [{ action: :changed, from: "Dataset", to: "" }],
      rights: [{ action: :changed, from: "Creative Commons Attribution 4.0 International", to: "" }],
      titles: [{ action: :changed, from: "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events ()", to: "new title ()" }],
      collection_tags: [{ action: :changed, from: "", to: "fake" }],
      creators: [{ action: :changed, from: "Kotin, Joshua | 1 | ", to: "" }],
      domains: [{ action: :changed, from: "", to: "Humanities" }]
    }
    resource1 = FactoryBot.create(:shakespeare_and_company_work).resource
    keys = resource1.as_json.keys.sort
    keys.each do |key|
      # If a new key is added to the resource, but the ResourceCompareService misses it,
      # we'll still test it here, and there should be a failure.
      it "correctly compares #{key}" do
        key_sym = key.to_sym
        setter = "#{key}=".to_sym
        resource2 = FactoryBot.create(:shakespeare_and_company_work).resource
        resource2.send(setter, new_values[key_sym])
        compare = described_class.new(resource1, resource2)
        expect(compare.differences[key_sym]).to eq expected_diff[key_sym]
      end
    end
  end

  describe "generic comparisons" do
    class MockResource < OpenStruct
      # We want to confirm that the compare service still works with new unexpected attributes.
      # This lets us treat a hash as if it were a resource.
      def as_json
        to_h
      end
    end

    class MockComparable < OpenStruct
      def compare_value
        to_h.to_yaml.sub("---\n", "")
      end
    end

    describe "value comparison" do
      it "does not flag integer->string as change" do
        compare = described_class.new(MockResource.new({ fake_year: 2000 }), MockResource.new({ fake_year: "2000" }))
        differences = compare.differences[:fake_year]
        expect(differences).to eq nil
      end

      it "does flag integer->string+1 as change" do
        compare = described_class.new(MockResource.new({ fake_year: 2000 }), MockResource.new({ fake_year: "2001" }))
        differences = compare.differences[:fake_year]
        expect(differences).to eq [{ action: :changed, from: "2000", to: "2001" }]
      end

      it "does flag string->nil as change" do
        compare = described_class.new(MockResource.new({ fake_year: "2000" }), MockResource.new({ fake_year: nil }))
        differences = compare.differences[:fake_year]
        expect(differences).to eq [{ action: :changed, from: "2000", to: "" }]
      end

      it "does flag nil->string as change" do
        compare = described_class.new(MockResource.new({ fake_year: nil }), MockResource.new({ fake_year: "2000" }))
        differences = compare.differences[:fake_year]
        expect(differences).to eq([{ action: :changed, from: "", to: "2000" }])
      end
    end

    describe "value array comparison" do
      it "flags change" do
        compare = described_class.new(MockResource.new({ fake_array: ["old"] }), MockResource.new({ fake_array: ["new"] }))
        expect(compare.differences).to eq({ fake_array: [{ action: :changed, from: "old", to: "new" }] })
      end
    end

    describe "object comparison" do
      it "flags change" do
        compare = described_class.new(MockResource.new({ fake_object: MockComparable.new({ field: "old" }) }), MockResource.new({ fake_object: MockComparable.new({ field: "new" }) }))
        expect(compare.differences).to eq({ fake_object: [{ action: :changed, from: ":field: old\n", to: ":field: new\n" }] })
      end
    end

    describe "object array comparison" do
      it "flags change" do
        compare = described_class.new(MockResource.new({ fake_object_array: [MockComparable.new({ field: "old" })] }), MockResource.new({ fake_object_array: [MockComparable.new({ field: "new" })] }))
        expect(compare.differences).to eq({ fake_object_array: [{ action: :changed, from: ":field: old\n", to: ":field: new\n" }] })
      end
    end
  end
end
