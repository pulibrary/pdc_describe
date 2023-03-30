# frozen_string_literal: true

FactoryBot.define do
  factory :s3_file, class: "S3File" do
    filename { "anyfile.txt" }
    last_modified { Time.zone.now }
    size { 10_759 }
    checksum { "abc123" }
    work { FactoryBot.create :draft_work }
    initialize_with do
      new(filename: filename, last_modified: last_modified, size: size,
          checksum: checksum, work: work)
    end

    factory :s3_readme do
      filename { "README.txt" }
    end
  end
end
