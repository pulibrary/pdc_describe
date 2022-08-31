# frozen_string_literal: true

FactoryBot.define do
  factory :collection do
    title { FFaker::Skill.tech_skill }
    code { FFaker::Code.npi }
  end
end
