# frozen_string_literal: true
require "rails_helper"

describe Metadata::Document do
  describe ".attribute_xpaths" do
    it "defaults to {}" do
      expect(described_class.attribute_xpaths).to eq({})
    end
  end
end
