# frozen_string_literal: true
require "factory_bot"
require "webmock/rspec"

FactoryBot.find_definitions

##
# These tasks will build the same sample data used in our systems specs in a
# development, staging, or production environment so we can interact with
# them more easily.
namespace :sample_data do
  desc "S3 sample data"
  task s3: :environment do
    RSpec::Mocks.with_temporary_scope do
      FactoryBot.create :shakespeare_and_company_dataset
    end
  end
end
