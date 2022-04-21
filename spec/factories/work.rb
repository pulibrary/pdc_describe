# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    factory :shakespeare_and_company_work do
      title { "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }
      collection { FactoryBot.create(:research_data) }
    end
  end
end
