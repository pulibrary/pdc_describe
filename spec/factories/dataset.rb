# frozen_string_literal: true

FactoryBot.define do
  factory :dataset do
    factory :shakespeare_and_company_dataset do
      doi { "https://doi.org/10.34770/pe9w-x904" }
      work { FactoryBot.create(:shakespeare_and_company_work) }
    end
  end
end
