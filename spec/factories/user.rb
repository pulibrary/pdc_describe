# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { FFaker::Internet.user_name }
    sequence(:email) { FFaker::Internet.email }
    provider { :cas }
  end
end
