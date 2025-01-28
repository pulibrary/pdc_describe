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

  task researchers_from_works: :environment do
    Work.all.each do |work|
      creators = work.resource.creators
      creators.each do |creator|
        if creator.identifier&.scheme == "ORCID"
          Researcher.new_researcher(creator.given_name, creator.family_name, creator.identifier.value, nil)
        end
      end
    end
  end
end
