# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    factory :research_data do
      title { "Research Data" }
      code { "RD" }
    end

    factory :library_resources do
      title { "Library Resources" }
      code { "LIB" }
    end
  end
end
