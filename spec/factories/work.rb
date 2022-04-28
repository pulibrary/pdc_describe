# frozen_string_literal: true

FactoryBot.define do
  factory :work do
    factory :shakespeare_and_company_work do
      title { "Shakespeare and Company Project Dataset: Lending Library Members, Books, Events" }
      collection { FactoryBot.create(:research_data) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :us_national_pandemic_report_work do
      title { "The U.S. National Pandemic Emotional Impact Report" }
      ark { "ark:/88435/dsp01h415pd635" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :fortune_100_blm_work do
      title { "The Fortune 100 and Black Lives Matter" }
      ark { "ark:/88435/dsp01hh63t004k" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :racial_wealth_gap_work do
      title { "The racial wealth gap: Why policy matters" }
      ark { "ark:/88435/dsp012z10wt38q" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :hungary_around_clock_work do
      title { "Hungary around the clock, January 5, 2022" }
      ark { "ark:/88435/dsp01w37639913" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :gu_dian_yan_jiu_work do
      title { "Gu dian yan jiu 古典研究; No. 9 (Spring 2012)" }
      ark { "ark:/88435/dsp01fx719q54q" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :racism_inequality_health_care_work do
      title { "Racism, inequality, and health care for African Americans" }
      ark { "ark:/88435/dsp01ng451m58f" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end

    factory :national_health_ukraine_work do
      title { "Nat︠s︡ional'ni rakhunky okhorony zdorov'i︠a︡ v Ukraïni u 2016 rot︠s︡i" }
      ark { "ark:/88435/dsp01zk51vk539" }
      collection { FactoryBot.create(:library_resources) }
      created_by_user_id { FactoryBot.create(:user).id }
    end
  end
end
