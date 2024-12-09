# frozen_string_literal: true
namespace :creators do
  desc "Creates default creators"
  task create_default_creators: :environment do
    User.all.each do |user|
      if user.orcid != nil
        Creator.new_creator(user.given_name, user.family_name, user.orcid, user.uid)
      end
    end
  end
end
