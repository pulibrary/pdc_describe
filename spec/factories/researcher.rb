# frozen_string_literal: true

FactoryBot.define do
  factory :researcher, class: "Researcher" do
    transient do
      groups_to_admin { [] }
    end
    first_name { FFaker::Name.name.split(" ").first }
    last_name { FFaker::Name.name.split(" ").last }
    orcid {"1111-2222-#{rand(1000).to_s.rjust(4,'0')}-#{rand(1000).to_s.rjust(4,'0')}"}
  end
end
