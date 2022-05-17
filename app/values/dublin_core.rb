# frozen_string_literal: true
class DublinCore
  def initialize(json)
    @json = json
  end

  delegate :present?, to: :attributes

  def attributes
    @attributes ||= json_object
  end

  def to_json(options = nil)
    attributes.to_h.to_json(options)
  end

  delegate :[], :[]=, to: :attributes
  delegate(
    :title,
    :creator,
    :subject,
    :date,
    :identifier,
    :language,
    :relation,
    :publisher,
    to: :attributes
  )

    private

      def json_object
        return {} if @json.nil?

        parsed = JSON.parse(@json)
        OpenStruct.new(parsed)
      end
end
