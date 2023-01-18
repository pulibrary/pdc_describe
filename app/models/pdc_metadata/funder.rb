# frozen_string_literal: true

module PDCMetadata
  class Funder
    attr_accessor :ror, :funder_name, :award_number, :award_uri

    class << self
      def funder_from_hash(funder)
        ror = funder["ror"]
        funder_name = funder["funder_name"]
        award_number = funder["award_number"]
        award_uri = funder["award_uri"]
        PDCMetadata::Funder.new(ror, funder_name, award_number, award_uri)
      end
    end

    def initialize(ror, funder_name, award_number, award_uri)
      @ror = ror
      @funder_name = funder_name
      @award_number = award_number
      @award_uri = award_uri
    end

    def compare_value
      "ROR: #{ror}\nFunder Name: #{funder_name}\nAward Number: #{award_number}\nAward URI: #{award_uri}"
    end
  end
end
