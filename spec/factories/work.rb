# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    factory :shakespeare_and_company_work do
      title { "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }
      collection { Collection.research_data }
      created_by_user_id { FactoryBot.create(:user).id }
    end
  end
end
