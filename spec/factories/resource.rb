# frozen_string_literal: true

FactoryBot.define do
  factory :resource, class: "PULDatacite::Resource" do
    transient do
      title { FFaker::Book.title }
    end
    # TODO: why does setting an idenifier make spec/system/work_spec.rb:72 fail
    # identifier { "https://doi.org/10.34770/123-abc" }
    # identifier_type { "DOI" }
    resource_type { "Dataset" }
    publisher { "Princeton University" }
    publication_year { "2020" }
    description { FFaker::Book.description }
    creators { [PULDatacite::Creator.new_person(FFaker::Name.first_name, FFaker::Name.last_name)] }
    titles { [PULDatacite::Title.new(title: title)] }
  end
end
