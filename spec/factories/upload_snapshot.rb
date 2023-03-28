# frozen_string_literal: true

FactoryBot.define do
  factory :upload_snapshot do
    url { "https://localhost.localdomain/file.txt" }
    version { 1 }
    work { FactoryBot.create(:approved_work) }
  end
end
