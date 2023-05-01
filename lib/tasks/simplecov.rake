# frozen_string_literal: true

require_relative "../../lib/simplecov_helper"

namespace :simplecov do
  desc "generate the SimpleCov coverage report"
  task report_coverage: :environment do |_t, args|
    minimum_coverage = if args.extras.empty?
                         100.0
                       else
                         first_arg = args.extras.first
                         first_arg.to_f
                       end
    SimpleCovHelper.report_coverage(minimum_coverage: minimum_coverage)
  end
end
