# frozen_string_literal: true

FactoryBot.define do
  factory :pul_datacite, class: "PULDatacite::Resource" do
    sequence(:identifier) { |n| "https://doi.org/10.1063/5.0000#{n}" }
    identifier_type { "DOI" }
    titles { [] << PULDatacite::Title.new(title: FFaker::Book.title) }
  end
end
