# frozen_string_literal: true

FactoryBot.define do
  factory :researcher, class: "Researcher" do
    transient do
      groups_to_admin { [] }
    end
    netid { FFaker::InternetSE.unique.login_user_name }
    first_name { FFaker::Name.name.split(" ").first }
    last_name { FFaker::Name.name.split(" ").last }
    orcid {"1111-0000-0000-1111"}
  end
end


