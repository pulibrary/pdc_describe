# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "User" do
    transient do
      collections_to_admin { [] }
    end
    uid { FFaker::InternetSE.unique.login_user_name }
    email { FFaker::InternetSE.unique.email }
    full_name { FFaker::Name.name }
    display_name { full_name.split(" ").first }
    provider { :cas }
    after(:create) do |user, evaluator|
      evaluator.collections_to_admin.each do |collection|
        user.add_role :collection_admin, collection
      end
    end

    factory :princeton_submitter do
      default_collection_id { Collection.default_for_department("12345").id }
    end

    factory :pppl_submitter do
      default_collection_id { Collection.default_for_department("31000").id }
    end
  end

  factory :super_admin_user, class: "User" do
    uid { FFaker::InternetSE.login_user_name }
    email { "#{uid}@princeton.edu" }
    provider { :cas }
    after(:create) do |user|
      User.new_super_admin(user.uid)
    end
  end
end
