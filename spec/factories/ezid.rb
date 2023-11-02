# frozen_string_literal: true
require "ezid-client"

FactoryBot.define do
  factory :ezid, class: Ezid::Identifier do
    sequence(:id) { |n| "ark:/99999/abc12345#{n}" }

    factory :ezid_with_redirection do
      target { "https://datacommons.princeton.edu/discovery/whatever" }
    end

    factory :ezid_without_redirection do
      target { "https://dataspace.princeton.edu/handle/#{id}" }
    end
  end
end
