# frozen_string_literal: true

class Work < ApplicationRecord
  class DublinCore
    def initialize(json)
      @json = json
    end

    def attributes
      @attributes ||= json_object
    end

    def key?(key)
      attributes.to_h.key?(key)
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

  belongs_to :collection

  before_save do |work|
    # Ensure that the metadata JSON is persisted properly
    if work.dublin_core.present?
      work.dublin_core = work.dublin_core.to_json
    end
  end

  def self.create_skeleton(title, user_id, collection_id, work_type)
    work = Work.new(
      title: title,
      created_by_user_id: user_id,
      collection_id: collection_id,
      work_type: work_type,
      state: "AWAITING-APPROVAL"
    )
    work.save!
    work
  end

  def dataset_id
    Dataset.where(work_id: id).first&.id
  end

  def approve(user)
    self.state = "APPROVED"
    save!
    track_state_change(user, "APPROVED")
  end

  def withdraw(user)
    self.state = "WITHDRAWN"
    save!
    track_state_change(user, "WITHDRAWN")
  end

  def resubmit(user)
    self.state = "AWAITING-APPROVAL"
    save!
    track_state_change(user, "AWAITING-APPROVAL")
  end

  def track_state_change(user, state)
    uw = UserWork.new(user_id: user.id, work_id: id, state: state)
    uw.save!
  end

  def state_history
    UserWork.where(work_id: id)
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def dublin_core
    DublinCore.new(super)
  end

  def dublin_core=(value)
    parsed = if value.is_a?(String)
               JSON.parse(value)
             else
               json_value = JSON.generate(value)
               JSON.parse(json_value)
             end

    super(parsed.to_json)
  rescue JSON::ParserError => parse_error
    raise(ArgumentError, "Invalid JSON passed to Work#dublin_core=: #{parse_error}")
  end
end
