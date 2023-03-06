# frozen_string_literal: true

FactoryBot.define do
  factory :upload_snapshot do
    uri { "https://localhost.localdomain/file.txt" }
    work { FactoryBot.create(:approved_work) }
  end
end
