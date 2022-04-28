# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    factory :shakespeare_and_company_work do
      title { "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }
      collection { FactoryBot.create(:research_data) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :us_national_pandemic_report_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
    factory :fortune_100_blm_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
    factory :racial_wealth_gap_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
    factory :hungary_around_clock_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
    factory :gu_dian_yan_jiu_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
    factory :racism_inequality_health_care_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
    factory :national_health_ukraine_work do
      title { "" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
  end
end
