# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { FFaker::InternetSE.login_user_name }
    sequence(:email) { FFaker::InternetSE.email }
    full_name { FFaker::Name.name }
    display_name { full_name.split(" ").first }
    provider { :cas }
  end

  factory :admin_user, class: "User" do
    sequence(:uid) { "fake1" }
    sequence(:email) { "fake1@princeton.edu" }
    provider { :cas }
  end
end
