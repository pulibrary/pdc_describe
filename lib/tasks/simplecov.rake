# frozen_string_literal: true

require_relative "../../lib/simplecov_helper"

namespace :simplecov do

  desc "generate the SimpleCov coverage report"
  task :report_coverage do
    SimpleCovHelper.report_coverage
  end
end
