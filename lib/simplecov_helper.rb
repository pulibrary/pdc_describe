# frozen_string_literal: true

require "active_support/inflector"
require "simplecov"

class SimpleCovHelper
  DEFAULT_BASE_DIR = "./coverage/"

  def self.report_coverage(base_dir: DEFAULT_BASE_DIR, minimum_coverage: 100)
    SimpleCov.configure do
      minimum_coverage(minimum_coverage)
    end

    built = new(base_dir:)
    built.merge_results
  end

  attr_reader :base_dir

  def initialize(base_dir:)
    @base_dir = base_dir
  end

  def all_results
    Dir["#{base_dir}/.resultset*.json"]
  end

  def merge_results
    SimpleCov.collate(all_results)
  end
end
