# frozen_string_literal: true

FactoryBot.define do
  factory :s3_file, class: "S3File" do
    filename { "anyfile.txt" }
    last_modified { Time.zone.now }
    size { 10_759 }
    checksum { "abc123" }
    query_service { nil }
    initialize_with do
      new(filename: filename, last_modified: last_modified, size: size,
          checksum: checksum, query_service: query_service)
    end
  end
end
