# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :collection

  before_save do |work|
    # Ensure that the metadata JSON is persisted properly
    if work.dublin_core.present?
      work.dublin_core = work.dublin_core.to_json
    elsif work.profile == "DATACITE" && work.ark.blank?
      work.ark = Ark.mint
    end
  end

  after_save do |work|
    # We only want to update the ark url under certain conditions.
    # Set this value in config/update_ark_url.yml
    if Rails.configuration.update_ark_url
      if work.ark.present?
        Ark.update(work.ark, work.url)
      end
    end
  end

  validate do |work|
    if work.ark.present?
      work.errors.add(:base, "Invalid ARK provided for the Work: #{work.ark}") unless Ark.valid?(work.ark)
    end

    if work.data_cite.present?
      work.errors.add(:base, "Must provide a title") if work.title.blank?
      work.errors.add(:base, "Must provide at least one Creator") if work.datacite_resource.creators.count == 0
      work.errors.add(:base, "Must indicate the Publisher") if work.datacite_resource.publisher.blank?
      work.errors.add(:base, "Must indicate the Publication Year") if work.datacite_resource.publication_year.blank?
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
  def self.create_dataset(title, user_id, collection_id, datacite_resource = nil, ark = nil)
    datacite_resource = PULDatacite::Resource.new(title: title) if datacite_resource.nil?
    work = Work.new(
      title: title,
      created_by_user_id: user_id,
      collection_id: collection_id,
      work_type: "DATASET",
      state: "AWAITING-APPROVAL",
      profile: "DATACITE",
      doi: "10.1234/tbd",
      data_cite: datacite_resource.to_json,
      ark: ark
    )
    # We skip the validation since we don't have all the required fields yet
    work.save!(validate: false)
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
    @datacite_resource ||= PULDatacite::Resource.new_from_json(data_cite)
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
