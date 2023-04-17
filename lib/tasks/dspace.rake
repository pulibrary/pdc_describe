# frozen_string_literal: true

namespace :dspace do
  # command line syntax: bundle exec rake orcid:populate\["orcid.csv"\]
  desc "migrate content of a work from dspace to aws"
  task :migrate_content, [:work_id] => [:environment] do |_, args|
    work_id = args[:work_id]
    work = Work.find(work_id)
    puts "Migrating Files from dspace to PDC for Work #{work.title}"
    dspace = PULDspaceData.new(work)
    filenames = dspace.download_bitstreams
    if filenames.any?(nil)
      bitstreams = dspace.bitstreams
      error_files = Hash[filenames.zip bitstreams].select { |key, _value| key.nil? }
      error_names = error_files.map { |bitstream| bitstream["name"] }.join(", ")
      raise "Error downloading file(s) #{error_names}"
    end
    results = dspace.upload_to_s3(filenames)
    errors = results.reject(&:"blank?")
    if errors.count > 0
      raise "Error uploading file(s):\n #{errors.join("\n")}"
    end
    puts "Sucessfully migrated #{filenames.count} files for work"
  end
end
