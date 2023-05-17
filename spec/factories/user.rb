# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: "User" do
    transient do
      groups_to_admin { [] }
    end
    uid { FFaker::InternetSE.unique.login_user_name }
    email { FFaker::InternetSE.unique.email }
    full_name { FFaker::Name.name }
    display_name { full_name.split(" ").first }
    provider { :cas }
    after(:create) do |user, evaluator|
      evaluator.groups_to_admin.each do |group|
        user.add_role :group_admin, group
      end
    end

    ##
    # A user who has submit rights on the PPPL Group
    factory :pppl_submitter do
      default_group_id { Group.default_for_department("31000").id }
    end

    ##
    # A user who has submit rights on the Research Data Group
    factory :princeton_submitter do
      default_group_id { Group.default_for_department("12345").id }
    end

    ##
    # A user who has admin rights on the PPPL Group
    factory :pppl_moderator do
      default_group_id { Group.default_for_department("31000").id }
      after :create do |user|
        user.add_role :group_admin, Group.plasma_laboratory
      end
    end

    ##
    # A user who has admin rights on the Research Data Group
    factory :research_data_moderator do
      default_group_id { Group.default_for_department("12345").id }
      after :create do |user|
        user.add_role :group_admin, Group.research_data
      end
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

  factory :external_user, class: "User" do
    uid { FFaker::InternetSE.user_name + "@gmail.com" }
    email { "#{uid}@princeton.edu" }
    provider { :cas }
  end
end
