# frozen_string_literal: true
require "csv"

require "rake"

namespace :orcid do

  # syntax on the command line: rake environment orcid:populate\["orcid.csv"\]
  desc "creates or updates user with ORCID information"
  task :populate, [:source] do |t, args|
    source = args[:source]
    User.create_users_from_csv(source)
  end
end
