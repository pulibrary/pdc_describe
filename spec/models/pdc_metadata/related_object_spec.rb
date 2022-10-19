# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::RelatedObject, type: :model do
  let(:related_identifier) { "https://www.biorxiv.org/content/10.1101/545517v1" }
  let(:related_identifier_type) { "arXiv" }
  let(:relation_type) { "IsCitedBy" }

  it "#new_related_object" do
    new_related_object = described_class.new_related_object(related_identifier, related_identifier_type, relation_type)
    expect(new_related_object.value).to eq related_identifier
  end
end
