# frozen_string_literal: true
require "csv"
require "rake"

namespace :orcid do
  # command line syntax: bundle exec rake orcid:populate\["orcid.csv"\]
  desc "creates or updates user with ORCID information"
  task :populate, [:source] => [:environment] do |_, args|
    source = args[:source]
    User.create_users_from_csv(source)
  end
end
