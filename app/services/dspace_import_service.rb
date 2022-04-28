# frozen_string_literal: true
require "faraday"

class DspaceImportService
  attr_reader :url, :collection, :user, :work_type

  def initialize(url:, user:, collection:, work_type: nil)
    @url = url
    @user = user
    @collection = collection
    @work_type = work_type
  end

  def self.metadata_class
    Metadata::DublinCore
  end

  def metadata
    @metadata ||= self.class.metadata_class.from_xml(document)
  end

  def title
    values = metadata.title || []
    values.first
  end

  def import!
    request!

    metadata.each_pair do |attr, values|
      dc_metadata = work.dublin_core
      dc_metadata[attr] = values

      work.dublin_core = dc_metadata

      # Save for each update in the DC metadata JSON Object
      work.save!
    end

    work
  end

  def work
    @work ||= Work.create_skeleton(title, user.id, collection.id, work_type)
  end

  private

    def client
      Faraday.new(
        url: url,
        params: {},
        headers: {
          "Content-Type" => "application/xml"
        }
      )
    end

    def request!
      @response ||= client.get
    end

    def document
      Nokogiri::XML.parse(@response.body)
    end
end
