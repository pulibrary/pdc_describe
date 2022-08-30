# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "User" do
    uid { FFaker::InternetSE.unique.login_user_name }
    email { FFaker::InternetSE.unique.email }
    full_name { FFaker::Name.name }
    display_name { full_name.split(" ").first }
    provider { :cas }

    factory :princeton_submitter do
      default_collection_id { Collection.default_for_department("12345").id }
      # After a user is created, their ID is added to the collections where they can deposit
      after(:create, &:setup_user_default_collections)
    end

    factory :pppl_submitter do
      default_collection_id { Collection.default_for_department("31000").id }
      after(:create, &:setup_user_default_collections)
    end
  end

  factory :super_admin_user, class: "User" do
    uid { FFaker::InternetSE.login_user_name }
    email { "#{uid}@princeton.edu" }
    provider { :cas }
    after(:create) do |user|
      user.add_role(:super_admin)
    end
  end
end
