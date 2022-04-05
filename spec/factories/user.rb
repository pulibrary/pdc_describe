# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:uid) { "pul123" }
    sequence(:email) { "pul123@princeton.edu" }
    provider { :cas }
  end
end
