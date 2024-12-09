# frozen_string_literal: true
namespace :researchers do
  desc "Creates default researchers"
  task create_default_researchers: :environment do
    User.all.each do |user|
      if user.orcid != nil
        Researcher.new_researcher(user.given_name, user.family_name, user.orcid, user.uid)
      end
    end
  end
end
