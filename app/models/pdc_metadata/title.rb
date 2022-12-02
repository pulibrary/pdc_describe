# frozen_string_literal: true
# Class for storing a title in our local representation
module PDCMetadata
  # value:      "100 años de soledad"
  # title_type: "TranslatedTitle"
  class Title
    attr_accessor :title, :title_type
    def initialize(title:, title_type: nil)
      @title = title
      @title_type = title_type
    end

    def main?
      @title_type.blank?
    end

    def compare_value
      "#{title} (#{title_type})"
    end
  end
end
