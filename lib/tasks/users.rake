# frozen_string_literal: true
namespace :users do
  desc "Creates user records for the users defined as the defaul collection administrators and submitters"
  task setup_default: :environment do
    User.create_default_users
  end

  desc "Updates users to make sure the super_admin role is set"
  task update_super_admins: :environment do
    User.update_super_admins
  end

  desc "Deletes existing user data and recreates the defaults."
  task reset_default: :environment do
    UserCollection.delete_all
    User.delete_all
    User.create_default_users
  end

  # Use this task to regenerate the collection_defaults.yml file with the data currently
  # in the database. This is useful to seed the data from one environment to another.
  desc "Outputs to the console the user/collection admin rights in YAML format"
  task export_admin_setup: :environment do
    puts "---"
    puts "shared:"
    Collection.all.each do |collection|
      puts "  #{collection.code.downcase}:"
      puts "    admin:"
      collection.administrators.each do |user|
        puts "      - #{user.uid}"
      end
      puts "    submit:"
      collection.submitters.each do |user|
        puts "      - #{user.uid}"
      end
    end
  end

  desc "Removes collections that we don't use anymore"
  task :collection_cleanup, [:fixit] => :environment do |_, args|
    fixit = (args[:fixit] == "true")
    if fixit
      puts "=> Fixing data"
    else
      puts "=> Showing data only"
    end

    puts "-- Processing UserCollection records"
    UserCollection.all.each do |uc|
      next if uc.collection.code == "RD" || uc.collection.code == "PPPL"
      puts "deleting collection #{uc.collection.code} from user #{uc.user.uid}"
      uc.delete if fixit
    end

    puts "-- User records"
    User.all.each do |user|
      next if user.default_collection.code == "RD" || user.default_collection.code == "PPPL"
      puts "fixing #{user.uid}, #{user.default_collection_id}, #{user.default_collection.code}"
      user.default_collection_id = Collection.research_data.id
      if fixit
        user.save!
        user.setup_user_default_collections
      end
    end

    puts "-- Work records"
    Work.all.each do |work|
      next if work.collection.code == "RD" || work.collection.code == "PPPL"
      puts "fixing work #{work.id}, #{work.collection_id}, #{work.collection.code}"
      work.collection_id = Collection.research_data.id
      work.save! if fixit
    end

    puts "-- Collection records"
    Collection.all.each do |collection|
      next if collection.code == "RD" || collection.code == "PPPL"
      puts "deleting collection #{collection.id}, #{collection.title}"
      collection.delete if fixit
    end
  end
end
