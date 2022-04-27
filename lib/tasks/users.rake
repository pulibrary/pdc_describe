# frozen_string_literal: true
namespace :users do
  desc "Creates user records for the users defined as the defaul collection administrators and submitters"
  task setup_default: :environment do
    # Uncomment these two lines if you really want to start from scratch
    UserCollection.delete_all
    User.delete_all
    User.create_default_users
  end
end
