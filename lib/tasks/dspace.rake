# frozen_string_literal: true

namespace :dspace do
  # command line syntax: bundle exec rake orcid:populate\["orcid.csv"\]
  desc "migrate content of a work from dspace to aws"
  task :migrate_content, [:work_id] => [:environment] do |_, args|
    work_id = args[:work_id]
    work = Work.find(work_id)
    puts "Migrating Files from dspace to PDC for Work #{work.title}"
    dspace = PULDspaceData.new(work)
    dspace.migrate
    puts "Sucessfully migrated #{dspace.keys.count} files for work"
  end
end
