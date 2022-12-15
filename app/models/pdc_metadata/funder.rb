# frozen_string_literal: true

module PDCMetadata
  class Funder
    attr_accessor :name, :award_number, :award_uri

    class << self
      def from_hash(funder)
        name = funder["name"]
        award_number = funder["award_number"]
        award_uri = funder["award_uri"]
        PDCMetadata::Creator.new(name, award_number, award_uri)
      end
    end

    def initialize(name, award_number, award_uri)
      @name = name
      @award_number = award_number
      @award_uri = award_uri
    end

    def compare_value
      "#{name} | #{award_number} | #{award_uri}"
    end
  end
end
