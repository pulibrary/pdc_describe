# frozen_string_literal: true

namespace :metadata do
  # command line syntax: bundle exec rake metadata:update_pppl_subcommunities\["netid"\]
  desc "Update renamed PPPL subcommunities"
  task :update_pppl_subcommunities, [:netid] => [:environment] do |_, args|
    netid = args[:netid]
    user = User.find_by(uid: netid)
    raise("No user found for id #{netid}") unless user
    WorkUpdateMetadataService.update_pppl_subcommunities(user, commandline: true)
    puts "Updated subcommunities metadata, recorded user #{netid} in WorkActivity"
  end
end
