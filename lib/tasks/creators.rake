# frozen_string_literal: true
namespace :creators do
  desc "Creates default creators"
  task create_default_creators: :environment do
    Creator.new_creator("claudia", "lee", "1111", "cl7359")
    Creator.new_creator("hector", "correa", "2222", "hc8719")
    
  end
end

#bundle exec rake -T : shows all rake tasks
# to run rake task: bundle exec rake creators:create_default_creators

#creator model: creates a fake creator with hardcoded values
#creator rake task: calls the creator model to create new creator ("default creators")
#creator controller: URL > routes > controller > rake task?
#create_creators migration file: creates table