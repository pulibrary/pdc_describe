# frozen_string_literal: true
namespace :users do
  desc "Creates user records for the users defined as the default group administrators and submitters"
  task setup_default: :environment do
    User.create_default_users
  end

  desc "Updates users to make sure the super_admin role is set"
  task update_super_admins: :environment do
    User.update_super_admins
  end

  desc "Deletes existing user data and recreates the defaults."
  task reset_default: :environment do
    Role.delete_all
    User.delete_all
    User.create_default_users
  end

  # Use this task to regenerate the group_defaults.yml file with the data currently
  # in the database. This is useful to seed the data from one environment to another.
  desc "Outputs to the console the user/group admin rights in YAML format"
  task export_admin_setup: :environment do
    puts "---"
    puts "shared:"
    Group.all.each do |group|
      puts "  #{group.code.downcase}:"
      puts "    admin:"
      group.administrators.each do |user|
        puts "      - #{user.uid}"
      end
      puts "    submit:"
      group.submitters.each do |user|
        puts "      - #{user.uid}"
      end
    end
  end
end
