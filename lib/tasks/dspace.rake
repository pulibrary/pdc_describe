# frozen_string_literal: true

namespace :dspace do
  # command line syntax: bundle exec rake orcid:populate\["orcid.csv"\]
  desc "migrate content of a work from dspace to aws"
  task :migrate_content, [:work_id] => [:environment] do |_, args|
    work_id = args[:work_id]
    work = Work.find(work_id)
    puts "Migrating Files from dspace to PDC for Work #{work.title}"
    dspace = PULDspaceMigrate.new(work)
    dspace.migrate
    puts dspace.migration_message
  end

  # command line syntax: bundle exec rake dspace:update_ark\["ark:/88435/dsp01k643b3527","https://datacommons.princeton.edu/discovery/\?f%5Bcommunities_ssim%5D%5B%5D\=Princeton+Plasma+Physics+Laboratory\&f%5Bsubcommunities_ssim%5D%5B%5D\=Advanced+Projects"]
  desc "update an ark to a new location"
  task :update_ark, [:ark, :new_location] => [:environment] do |_, args|
    ark = args[:ark]
    new_location = args[:new_location]
    Ark.update(ark, new_location, command_line: true)
    a = Ark.new(ark)
    if a.target == new_location
      puts "Update successful!"
    else
      puts "Unable to update ark."
    end
  end
end
