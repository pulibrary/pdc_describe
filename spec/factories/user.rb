# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { FFaker::InternetSE.login_user_name }
    sequence(:email) { FFaker::InternetSE.email }
    default_collection_id { Collection.research_data.id }
    full_name { FFaker::Name.name }
    display_name { full_name.split(" ").first }
    provider { :cas }
  end

  factory :super_admin_user, class: "User" do
    sequence(:uid) { "fake1" }
    sequence(:email) { "fake1@princeton.edu" }
    provider { :cas }
  end
end
