# frozen_string_literal: true

FactoryBot.define do
  factory :resource, class: "PULDatacite::Resource" do
    transient do
      title { "test title" }
    end
    description { "description of the test dataset" }
    creators { [PULDatacite::Creator.new_person("Harriet", "Tubman")] }
    titles { [PULDatacite::Title.new(title: title)] }
  end
end
