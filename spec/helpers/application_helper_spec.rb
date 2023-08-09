# frozen_string_literal: true
require "rails_helper"

RSpec.describe ApplicationHelper do
  before(:all) do
    class TestController
      include ApplicationHelper
    end
  end

  after(:all) do
    Object.send(:remove_const, :TestController)
  end

  let(:test_controller) { TestController.new }

  describe "#html_tag_attributes" do
    it "generates the HTML attributes for the <html>" do
      expect(test_controller.html_tag_attributes).to eq({ lang: :en })
    end
  end

  describe "#ark_url" do
    let(:ark_value) { "test-ark" }
    let(:output) { test_controller.ark_url(ark_value) }

    it "builds a URL" do
      expect(output).to eq("http://arks.princeton.edu/test-ark")
    end

    context "when the ark value is blank" do
      let(:ark_value) { "" }

      it "builds a URL" do
        expect(output).to be nil
      end
    end
  end

  describe "#doi_url" do
    let(:doi_value) { "test-doi" }
    let(:output) { test_controller.doi_url(doi_value) }

    it "builds a URL" do
      expect(output).to eq("https://doi.org/test-doi")
    end

    context "when the ark value is blank" do
      let(:doi_value) { "" }

      it "builds a URL" do
        expect(output).to be nil
      end
    end
  end

  describe "#pre_curation_uploads_file_name" do
    let(:file) { double }
    let(:input) { "a" * 100 }
    let(:output) { test_controller.pre_curation_uploads_file_name(file: file) }

    before do
      allow(file).to receive(:filename).and_return(input)
    end

    it "truncates the file name to 80 characters" do
      expect(file.filename.length).to eq(100)
      expect(output.length).to eq(80)
    end

    context "when the file name is blank" do
      let(:input) { "" }

      it "returns nil" do
        expect(output).to be nil
      end
    end
  end
end
