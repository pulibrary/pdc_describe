# frozen_string_literal: true

require "rails_helper"

# rubocop:disable Layout/LineLength
# rubocop:disable RSpec/ExampleLength
RSpec.describe DatasetCitation do
  let(:work) do
    resource = FactoryBot.build :resource, title: "Compact steady-state tokamak"
    work = FactoryBot.create :draft_work, resource: resource
    work.resource.creators.first.given_name = "J.E."
    work.resource.creators.first.family_name = "Menard"
    work.resource.publication_year = 2018
    work.resource.resource_type = "Data set"
    work.resource.doi = "http://doi.org/princeton/test123"
    work
  end
  let(:creators) { work.resource.creators.map { |creator| "#{creator.family_name}, #{creator.given_name}" } }
  let(:single_author_dataset) { described_class.new(creators, [work.resource.publication_year], work.resource.titles.first.title, work.resource.resource_type, work.resource.publisher, work.resource.doi) }
  let(:two_authors_dataset) { described_class.new(["Menard, J.E.", "Lopez, R."], [2018], "Compact steady-state tokamak", "Data set", "Princeton University", "http://doi.org/princeton/test123") }
  let(:three_authors_dataset) { described_class.new(["Menard, J.E.", "Lopez, R.", "Liu, D."], [2018], "Compact steady-state tokamak", "Data set", "Princeton University", "http://doi.org/princeton/test123") }

  describe "#apa" do
    it "handles authors correctly" do
      expect(single_author_dataset.apa).to eq "Menard, J.E. (2018). Compact steady-state tokamak [Data set]. Princeton University. http://doi.org/princeton/test123"
      expect(two_authors_dataset.apa).to eq "Menard, J.E. & Lopez, R. (2018). Compact steady-state tokamak [Data set]. Princeton University. http://doi.org/princeton/test123"
      expect(three_authors_dataset.apa).to eq "Menard, J.E., Lopez, R., & Liu, D. (2018). Compact steady-state tokamak [Data set]. Princeton University. http://doi.org/princeton/test123"
    end
  end

  describe "#bibtex" do
    it "returns correct format" do
      bibtex = "@electronic{menard_je_2018,\r\n" \
      "\tauthor      = {Menard, J.E.},\r\n" \
      "\ttitle       = {{Compact steady-state tokamak}},\r\n" \
      "\tpublisher   = {{Princeton University}},\r\n" \
      "\tyear        = 2018,\r\n" \
      "\turl         = {http://doi.org/princeton/test123}\r\n" \
      "}"
      expect(single_author_dataset.bibtex).to eq bibtex
    end
  end

  describe "title" do
    it "does not add extra periods to title and publisher if they come in the source data" do
      citation = described_class.new(["Menard, J.E."], [2018], "Compact steady-state tokamak.", "Data set", "Princeton University.", "http://doi.org/princeton/test123")
      expect(citation.apa).to eq "Menard, J.E. (2018). Compact steady-state tokamak [Data set]. Princeton University. http://doi.org/princeton/test123"
    end
  end

  describe "year" do
    it "handles year ranges" do
      citation = described_class.new(["Menard, J.E."], [2018, 2020], "Compact steady-state tokamak.", "Data set", "Princeton University.", "http://doi.org/princeton/test123")
      expect(citation.apa).to eq "Menard, J.E. (2018-2020). Compact steady-state tokamak [Data set]. Princeton University. http://doi.org/princeton/test123"
    end
  end

  describe "#custom_strip" do
    it "custom trailing characters" do
      expect(described_class.custom_strip("Some title.")).to eq "Some title"
      expect(described_class.custom_strip("Some title..")).to eq "Some title"
      expect(described_class.custom_strip("Some title")).to eq "Some title"
      expect(described_class.custom_strip("Some title, ")).to eq "Some title"
      expect(described_class.custom_strip("Some title, .")).to eq "Some title"
      expect(described_class.custom_strip("")).to eq ""
      expect(described_class.custom_strip(nil)).to eq nil
      expect(described_class.custom_strip(" . , ")).to eq ""
    end
  end

  describe "#bibtex_lines" do
    it "breaks lines as expected" do
      citation = described_class.new("", [], "", "", "", "")
      expect(citation.bibtex_lines("hello world", 20)).to eq ["hello world"]
      expect(citation.bibtex_lines("this is a very long text", 20)).to eq ["this is a very long ", "text"]
      expect(citation.bibtex_lines(0)).to eq ["0"]
      expect(citation.bibtex_lines(nil)).to eq [""]
    end
  end

  describe "#to_s" do
    it "converts BibTeX to string" do
      bibtex = "@electronic{menard_je_2018,\r\n" \
      "\tauthor      = {Menard, J.E.},\r\n" \
      "\ttitle       = {{Compact steady-state tokamak}},\r\n" \
      "\tpublisher   = {{Princeton University}},\r\n" \
      "\tyear        = 2018,\r\n" \
      "\turl         = {http://doi.org/princeton/test123}\r\n" \
      "}"
      expect(single_author_dataset.bibtex).to eq bibtex
      expect(single_author_dataset.to_s("BibTeX")).to eq(bibtex)
    end

    it "converts APA to string" do
      apa = "Menard, J.E. (2018). Compact steady-state tokamak [Data set]. Princeton University. http://doi.org/princeton/test123"
      expect(single_author_dataset.to_s("apa")).to eq(apa)
    end
  end
end
# rubocop:enable RSpec/ExampleLength
# rubocop:enable Layout/LineLength
