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

    ##
    # A user who has submit rights on the PPPL Collection
    factory :pppl_submitter do
      default_collection_id { Collection.default_for_department("31000").id }
      # After a user is created, their ID is added to the collections where they can deposit
      after(:create, &:setup_user_default_collections)
    end

    ##
    # A user who has submit rights on the Research Data Collection
    factory :princeton_submitter do
      default_collection_id { Collection.default_for_department("12345").id }
    end

    ##
    # A user who has admin rights on the PPPL Collection
    factory :pppl_admin do
      default_collection_id { Collection.default_for_department("31000").id }
      after :create do |user|
        user.add_role :collection_admin, Collection.plasma_laboratory
      end
    end

    ##
    # A user who has admin rights on the Research Data Collection
    factory :research_data_admin do
      default_collection_id { Collection.default_for_department("12345").id }
      after :create do |user|
        user.add_role :collection_admin, Collection.research_data
      end
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
