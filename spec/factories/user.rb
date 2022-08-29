# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "User" do
    sequence(:uid) { FFaker::InternetSE.login_user_name }
    sequence(:email) { FFaker::InternetSE.email }
    # default_collection_id { Collection.research_data.id }
    full_name { FFaker::Name.name }
    display_name { full_name.split(" ").first }
    provider { :cas }

    factory :princeton_submitter do
      default_collection_id { Collection.default_for_department("12345").id }
    end

    factory :pppl_submitter do
      default_collection_id { Collection.default_for_department("31000").id }
    end
  end

  factory :super_admin_user, class: "User" do
    sequence(:uid) { "fake1" }
    sequence(:email) { "fake1@princeton.edu" }
    provider { :cas }
  end

  # After a user is created, their ID is added to the collections where they can deposit
  after(:create) do |user|
    user.setup_user_default_collections
  end
  
end
