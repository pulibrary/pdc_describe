# frozen_string_literal: true
require "rails_helper"

RSpec.describe PDCMetadata::Creator, type: :model do
  let(:first_name) { "Elizabeth" }
  let(:last_name) { "Miller" }
  let(:orcid) { "1234-5678-9012-1234" }

  it "#new_person" do
    new_person = described_class.new_person(first_name, last_name, orcid)
    expect(new_person.value).to eq "Miller, Elizabeth"
  end
end
