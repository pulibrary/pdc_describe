# frozen_string_literal: true

module Metadata
  class DublinCore < Base
    def self.document_class
      OaiPmhDocument
    end

    def self.attribute_names
      super + [
        :title,
        :creator,
        :subject,
        :date,
        :identifier,
        :language,
        :relation,
        :publisher
      ]
    end
  end
end
