# frozen_string_literal: true
namespace :servers do
  task initialize: :environment do
    Rake::Task["db:create"].invoke
    Rake::Task["db:migrate"].invoke
    Rake::Task["db:seed"].invoke
  end

  desc "Starts development dependencies"
  task start: :environment do
    system("lando start")
    system("rake servers:initialize")
    system("rake servers:initialize RAILS_ENV=test")
  end

  desc "Stop development dependencies"
  task stop: :environment do
    system "lando stop"
  end

  task reset_users: :environment do
    # UserCollection.delete_all
    # User.delete_all
    User.create_default_users
  end
end
