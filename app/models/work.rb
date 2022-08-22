# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  has_many :work_activity, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many_attached :deposit_uploads
  belongs_to :collection

  attribute :work_type, :string, default: "DATASET"
  attribute :profile, :string, default: "DATACITE"

  include AASM

  aasm column: :state do
    state :none, inital: true
    state :draft, :awaiting_approval, :approved, :withdrawn, :tombstone

    event :draft, after: :draft_doi do
      transitions from: :none, to: :draft, guard: :valid_to_draft
    end

    event :complete_submission do
      transitions from: :draft, to: :awaiting_approval, guard: :valid_to_submit
    end

    event :request_changes do
      transitions from: :awaiting_approval, to: :awaiting_approval, guard: :valid_to_submit
    end

    event :approve do
      transitions from: :awaiting_approval, to: :approved, guard: :valid_to_submit, after: :publish
    end

    event :withdraw do
      transitions from: [:draft, :awaiting_approval, :approved], to: :withdrawn
    end

    event :resubmit do
      transitions from: :withdrawn, to: :draft
    end

    event :remove do
      transitions from: :withdrawn, to: :tombstone
    end

    after_all_events :track_state_change
  end

  class << self
    def create_skeleton(title, user_id, collection_id, work_type, profile)
      resource = PDCMetadata::Resource.new(title: title,
                                           creators: [PDCMetadata::Creator.new_person("", "skeleton", "", 0)],
                                           description: title)
      work = Work.new(
        created_by_user_id: user_id,
        collection_id: collection_id,
        work_type: work_type,
        state: "awaiting_approval",
        profile: profile,
        metadata: resource.to_json
      )
      work.save!
      work
    end

    def unfinished_works(user)
      works_by_user_state(user, ["none", "draft", "awaiting_approval"])
    end

    def completed_works(user)
      works_by_user_state(user, "approved")
    end

    def withdrawn_works(user)
      works_by_user_state(user, "withdrawn")
    end

    private

      def works_by_user_state(user, state)
        works = []
        if user.admin_collections.count == 0
          # Just the user's own works by state
          works += Work.where(created_by_user_id: user, state: state)
        else
          # The works that match the given state, in all the collections the user can admin
          # (regardless of who created those works)
          user.admin_collections.each do |collection|
            works += Work.where(collection_id: collection.id, state: state)
          end
        end

        # Any other works where the user is mentioned
        works_mentioned_by_user_state(user, state).each do |work|
          already_included = !works.find { |existing_work| existing_work[:id] == work.id }.nil?
          works << work unless already_included
        end

        works.sort_by(&:updated_at).reverse
      end

      # Returns an array of work ids where a particular user has been mentioned
      # and the work is in a given state.
      def works_mentioned_by_user_state(user, state)
        Work.joins(:work_activity)
            .joins('INNER JOIN "work_activity_notifications" ON "work_activities"."id" = "work_activity_notifications"."work_activity_id"')
            .where(state: state)
            .where('"work_activity_notifications"."user_id" = ?', user.id)
      end
  end

  include Rails.application.routes.url_helpers

  before_save do |work|
    # Ensure that the metadata JSON is persisted properly
    work.metadata = work.resource.to_json

    new_attachments = work.deposit_uploads.reject(&:persisted?)
    new_attachments.each do |attachment|
      attachment_key = generate_attachment_key(attachment)
      attachment.key = attachment_key

      attachment.blob.save
      attachment.save
    end
  end

  validate do |work|
    if none?
      true
    elsif draft?
      work.valid_to_draft
    else
      work.valid_to_submit
    end
  end

  def valid_to_draft
    errors.clear
    errors.add(:base, "Must provide a title") if resource.main_title.blank?
    validate_ark
    validate_creators
    validate_uploads
    errors.count == 0
  end

  def valid_to_submit
    valid_to_draft
    validate_metadata
    errors.count == 0
  end

  def validate_uploads
    if deposit_uploads.length > 20
      errors.add(:base, "Only 20 files may be uploaded by a user to a given Work. #{deposit_uploads.length} files were uploaded for the Work: #{ark}")
    end
  end

  def title
    resource.main_title
  end

  def curator
    return nil if curator_user_id.nil?
    User.find(curator_user_id)
  end

  def draft_doi
    resource.doi ||= if Rails.env.development? && ENV["DATACITE_USER"].blank?
                       Rails.logger.info "Using hard-coded test DOI during development."
                       "10.34770/tbd"
                     else
                       result = data_cite_connection.autogenerate_doi(prefix: ENV["DATACITE_PREFIX"])
                       if result.success?
                         result.success.doi
                       else
                         raise("Error generating DOI. #{result.failure.status} / #{result.failure.reason_phrase}")
                       end
                     end
  end

  def state_history
    UserWork.where(work_id: id).order(updated_at: :desc)
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def resource
    @resource ||= PDCMetadata::Resource.new_from_json(metadata)
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

  def files_location_upload?
    files_location.blank? || files_location == "file_upload"
  end

  def files_location_cluster?
    files_location == "file_cluster"
  end

  def files_location_other?
    files_location == "file_other"
  end

  def change_curator(curator_user_id, current_user)
    if curator_user_id == "no-one"
      clear_curator(current_user)
    else
      update_curator(curator_user_id, current_user)
    end
  end

  def clear_curator(current_user)
    # Update the curator on the Work
    self.curator_user_id = nil
    save!

    # ...and log the activity
    WorkActivity.add_system_activity(id, "Unassigned existing curator", current_user.id)
  end

  def update_curator(curator_user_id, current_user)
    # Update the curator on the Work
    self.curator_user_id = curator_user_id
    save!

    # ...and log the activity
    curator = User.find(curator_user_id)
    message = if curator_user_id == current_user.id
                "Self-assigned as curator"
              else
                "Set curator to @#{curator.uid}"
              end
    WorkActivity.add_system_activity(id, message, current_user.id)
  end

  def add_comment(comment, current_user)
    WorkActivity.add_system_activity(id, comment, current_user.id, activity_type: "COMMENT")
  end

  def activities
    WorkActivity.where(work_id: id).sort_by(&:updated_at).reverse
  end

  def new_notification_count_for_user(user_id)
    WorkActivityNotification.joins(:work_activity)
                            .where(user_id: user_id, read_at: nil)
                            .where(work_activity: { work_id: id })
                            .count
  end

  # Marks as read the notifications for the given user_id in this work.
  # In practice, the user_id is the id of the current user and therefore this method marks the current's user
  # notifications as read.
  def mark_new_notifications_as_read(user_id)
    activities.each do |activity|
      unread_notifications = WorkActivityNotification.where(user_id: user_id, work_activity_id: activity.id, read_at: nil)
      unread_notifications.each do |notification|
        notification.read_at = Time.now.utc
        notification.save
      end
    end
  end

  def current_transition
    aasm.current_event.to_s.humanize.delete("!")
  end

  private

    def publish(user)
      publish_doi(user)
      update_ark_information
    end

    # Update EZID (our provider of ARKs) with the new information for this work.
    def update_ark_information
      # We only want to update the ark url under certain conditions.
      # Set this value in config/update_ark_url.yml
      if Rails.configuration.update_ark_url
        if ark.present?
          Ark.update(ark, url)
        end
      end
    end

    def generate_attachment_key(attachment)
      key_base = "#{doi}/#{id}"

      attachment_filename = attachment.filename.to_s
      attachment_key = [key_base, attachment_filename].join("/")

      attachment_ext = File.extname(attachment_filename)
      attachment_query = attachment_key.gsub(attachment_ext, "")
      results = ActiveStorage::Blob.where("key LIKE :query", query: "%#{attachment_query}%")
      blobs = results.to_a

      if blobs.present?
        index = blobs.length + 1
        attachment_key = attachment_key.gsub(/\.([a-zA-Z0-9\.]+)$/, "_#{index}.\\1")
      end

      attachment_key
    end

    def track_state_change(user, state = aasm.to_state)
      uw = UserWork.new(user_id: user.id, work_id: id, state: state)
      uw.save!
      WorkActivity.add_system_activity(id, "marked as #{state}", user.id)
    end

    def data_cite_connection
      @data_cite_connection ||= Datacite::Client.new(username: ENV["DATACITE_USER"],
                                                     password: ENV["DATACITE_PASSWORD"],
                                                     host: ENV["DATACITE_HOST"])
    end

    def validate_ark
      if ark.present?
        errors.add(:base, "Invalid ARK provided for the Work: #{ark}") unless Ark.valid?(ark)
      end
    end

    def validate_metadata
      return if metadata.blank?
      errors.add(:base, "Must provide a title") if resource.main_title.blank?
      errors.add(:base, "Must provide a description") if resource.description.blank?
      errors.add(:base, "Must indicate the Publisher") if resource.publisher.blank?
      errors.add(:base, "Must indicate the Publication Year") if resource.publication_year.blank?
      validate_creators
    end

    def validate_creators
      if resource.creators.count == 0
        errors.add(:base, "Must provide at least one Creator")
      else
        resource.creators.each do |creator|
          if creator.orcid.present? && Orcid.invalid?(creator.orcid)
            errors.add(:base, "ORCID for creator #{creator.value} is not in format 0000-0000-0000-0000")
          end
        end
      end
    end

    def publish_doi(user)
      if Rails.env.development? && ENV["DATACITE_USER"].blank?
        Rails.logger.info "Publishing hard-coded test DOI during development."
      else
        result = data_cite_connection.update(id: doi, attributes: doi_attributes)
        if result.failure?
          message = "@#{curator_or_current_uid(user)} Error publishing DOI. #{result.failure.status} / #{result.failure.reason_phrase}"
          WorkActivity.add_system_activity(id, message, user.id, activity_type: "DATACITE_ERROR")
        end
      end
    end

    def curator_or_current_uid(user)
      curator = if curator_user_id
                  User.find(curator_user_id)
                else
                  user
                end
      curator.uid
    end

    def doi_attributes
      {
        "event" => "publish",
        "xml" => Base64.encode64(ValidDatacite::Resource.new_from_json(metadata).to_xml),
        "url" => "https://schema.datacite.org/meta/kernel-4.0/index.html" # TODO: this should be a link to the item in PDC-discovery
      }
    end
end
# rubocop:ensable Metrics/ClassLength
