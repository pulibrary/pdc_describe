# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :collection

  before_save do |work|
    # Ensure that the metadata JSON is persisted properly
    if work.dublin_core.present?
      work.dublin_core = work.dublin_core.to_json
    end
  end

  before_update do |ds|
    if dublin_core.present?
      # we don't mint ARKs for these records
    elsif ds.ark.blank?
      ds.ark = Ark.mint
    end
  end

  after_save do |ds|
    # We only want to update the ark url under certain conditions.
    # Set this value in config/update_ark_url.yml
    if Rails.configuration.update_ark_url
      if ds.ark.present?
        # Ensure that the ARK metadata is updated for the new URL
        if ark_object.target != ds.url
          ark_object.target = ds.url
          ark_object.save!
        end
      end
    end
  end

  validate do |work|
    if work.ark.present?
      work.errors.add(:base, "Invalid ARK provided for the Work: #{work.ark}") unless Ark.valid?(work.ark)
    end

    unless datacite_resource.nil?
      if datacite_resource.main_title.blank?
        work.errors.add(:base, "Must provide a title")
      end
    end
  end

  def self.create_skeleton(title, user_id, collection_id, work_type, profile)
    work = Work.new(
      title: title,
      created_by_user_id: user_id,
      collection_id: collection_id,
      work_type: work_type,
      state: "AWAITING-APPROVAL",
      profile: profile
    )
    work.save!
    work
  end

  # Convenience method to create Datasets with the DataCite profile
  def self.create_dataset(title, user_id, collection_id)
    work = Work.new(
      title: title,
      created_by_user_id: user_id,
      collection_id: collection_id,
      work_type: "DATASET",
      state: "AWAITING-APPROVAL",
      profile: "DATACITE"
    )
    work.save!
    work
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

  def datacite_resource
    return nil if data_cite.blank?
    @datacite_resource ||= Datacite::Resource.new_from_json(data_cite)
  end

  def ark_url
    "https://ezid.cdlib.org/id/#{ark}"
  end

  def ark_object
    @ark_object ||= Ark.new(ark)
  end

  def url
    return unless persisted?

    @url ||= url_for(self)
  end

  def self.my_works(user)
    Work.where(created_by_user_id: user)
  end

  def self.admin_awaiting_works(user)
    admin_works_by_user_state(user, "AWAITING-APPROVAL")
  end

  def self.admin_withdrawn_works(user)
    admin_works_by_user_state(user, "WITHDRAWN")
  end

  # Returns that works that an admin user has in a given state.
  #
  # Notice that it *excludes* the works created by the admin user
  # (since their own works will already be shown on their dashboard)
  def self.admin_works_by_user_state(user, state)
    admin_collections = []
    Collection.all.find_each do |collection|
      admin_collections << collection if user.can_admin?(collection.id)
    end

    works = []
    admin_collections.each do |collection|
      condition = "collection_id = :collection_id AND state = :state AND (created_by_user_id != :user_id)"
      values = { collection_id: collection.id, state: state, user_id: user.id }
      works += Work.where([condition, values])
    end

    works
  end
end
# rubocop:ensable Metrics/ClassLength
