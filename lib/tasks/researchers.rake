# frozen_string_literal: true
namespace :researchers do
  desc "Creates researchers records from user records"
  task create_from_users: :environment do
    User.all.each do |user|
      unless user.orcid.nil?
        Researcher.new_researcher(user.given_name, user.family_name, user.orcid)
        puts "Added researcher: #{user.given_name} #{user.family_name}"
      end
    end
  end

  desc "Creates researchers records from data in existing datasets"
  task create_from_works: :environment do
    Work.all.each do |work|
      work.resource.creators.each do |creator|
        if creator.identifier&.scheme == "ORCID" && creator.identifier.value.present?
          Researcher.new_researcher(creator.given_name, creator.family_name, creator.identifier.value)
          puts "Added researcher: #{creator.given_name} #{creator.family_name}"
        end
      end
    end
  end
end
