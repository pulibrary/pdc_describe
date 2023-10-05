# frozen_string_literal: true

FactoryBot.define do
  factory :resource, class: "PDCMetadata::Resource" do
    transient do
      title { FFaker::Book.title }
    end
    # TODO: why does setting an idenifier make spec/system/work_spec.rb:72 fail
    # identifier { "https://doi.org/10.34770/123-abc" }
    # identifier_type { "DOI" }
    resource_type { "Dataset" }
    resource_type_general { "Dataset" }
    publisher { "Princeton University" }
    publication_year { "2020" }
    description { FFaker::Book.description }
    creators { [PDCMetadata::Creator.new_person(FFaker::Name.first_name, FFaker::Name.last_name)] }
    titles { [PDCMetadata::Title.new(title:)] }
    rights_many { [PDCMetadata::Rights.find("CC BY")] }
    version_number { "1" }
  end

  factory :new_resource, class: "PDCMetadata::Resource" do
    # These should only have the following:
    # publication year
    # resource_type
    # resource type general
    # version number
    resource_type { "Dataset" }
    resource_type_general { "Dataset" }
    publisher { nil }
    publication_year { "2020" }
    creators { [] }
    titles { [] }
    version_number { "1" }
    description { nil }
    rights_many { [] }
  end

  factory :draft_resource, class: "PDCMetadata::Resource" do
    transient do
      title { FFaker::Book.title }
    end

    # These should only have the following:
    # title(s)
    # creator(s)
    # doi
    # publisher
    # publication year
    # resource_type
    # resource type general
    # version number
    resource_type { "Dataset" }
    resource_type_general { "Dataset" }
    publisher { "Princeton University" }
    publication_year { "2020" }
    creators { [PDCMetadata::Creator.new_person(FFaker::Name.first_name, FFaker::Name.last_name)] }
    titles { [PDCMetadata::Title.new(title:)] }
    version_number { "1" }
    description { nil }
    rights_many { [] }
  end
end
