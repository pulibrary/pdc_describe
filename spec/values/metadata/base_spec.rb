# frozen_string_literal: true
require "rails_helper"

describe Metadata::Base do
  describe ".document_class" do
    it "defaults to Metadata::Document" do
      expect(described_class.document_class).to eq(Metadata::Document)
    end
  end
end
