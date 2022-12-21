# frozen_string_literal: true

module PDCMetadata
  class Funder
    attr_accessor :funder_name, :award_number, :award_uri

    class << self
      def funder_from_hash(funder)
        funder_name = funder["funder_name"]
        award_number = funder["award_number"]
        award_uri = funder["award_uri"]
        PDCMetadata::Funder.new(funder_name, award_number, award_uri)
      end
    end

    def initialize(funder_name, award_number, award_uri)
      @funder_name = funder_name
      @award_number = award_number
      @award_uri = award_uri
    end

    def compare_value
      "#{funder_name} | #{award_number} | #{award_uri}"
    end
  end
end
