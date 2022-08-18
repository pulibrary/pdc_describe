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

    event :ready_for_review do
      transitions from: :draft, to: :awaiting_approval, guard: :valid_to_submit
    end

    event :request_changes do
      transitions from: :awaiting_approval, to: :awaiting_approval, guard: :valid_to_submit
    end

    event :approve do
      transitions from: :awaiting_approval, to: :approved, guard: :valid_to_submit
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
      resource = PULDatacite::Resource.new(title: title,
                                           creators: [PULDatacite::Creator.new_person("", "skeleton", "", 0)],
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

    # Convenience method to create Datasets with the DataCite profile
    def create_dataset(user_id, collection_id, resource, ark = nil)
      work = default_work(user_id, collection_id, resource, ark)
      work.draft_doi

      # We skip the validation since we don't have all the required fields yet
      work.save!(validate: false)
      work
    end

    def unfinished_works(user)
      works_by_user_state(user, "awaiting_approval")
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
        works_mentioned_by_user_state(user, state).each do |work_id|
          already_included = !works.find { |work| work[:id] == work_id }.nil?
          works << Work.find(work_id) unless already_included
        end

        works.sort_by(&:updated_at).reverse
      end

      # Returns an array of work ids where a particular user has been mentioned
      # and the work is in a given state.
      def works_mentioned_by_user_state(user, state)
        sql = <<-END_SQL
          SELECT DISTINCT works.id
          FROM works
          INNER JOIN work_activities ON works.id = work_activities.work_id
          INNER JOIN work_activity_notifications ON work_activities.id = work_activity_notifications.work_activity_id
          WHERE work_activity_notifications.user_id = #{user.id} AND works.state = '#{state}'
        END_SQL
        rows = ActiveRecord::Base.connection.execute(sql)
        rows.map { |row| row["id"] }
      end

      def default_work(user_id, collection_id, resource, ark)
        Work.new(
          created_by_user_id: user_id,
          collection_id: collection_id,
          work_type: "DATASET",
          state: "awaiting_approval",
          profile: "DATACITE",
          doi: nil,
          metadata: resource.to_json,
          ark: ark
        )
      end
  end

  include Rails.application.routes.url_helpers

  before_save do |work|
    # Ensure that the metadata JSON is persisted properly
    if work.profile == "DATACITE" && work.ark.blank?
      work.ark = Ark.mint
    end

    work.metadata = work.resource.to_json

    new_attachments = work.deposit_uploads.reject(&:persisted?)
    new_attachments.each do |attachment|
      attachment_key = generate_attachment_key(attachment)
      attachment.key = attachment_key

      attachment.blob.save
      attachment.save
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
    if none?
      true
    elsif draft?
      work.valid_to_draft
    else
      work.valid_to_submit
    end
  end

  def valid_to_draft
    errors.add(:base, "Must provide a title") if resource.main_title.blank?
    validate_creators
  end

  def valid_to_submit
    errors.clear
    validate_ark
    validate_metadata
    if deposit_uploads.length > 20
      errors.add(:base, "Only 20 files may be uploaded by a user to a given Work. #{deposit_uploads.length} files were uploaded for the Work: #{ark}")
    end
    errors.count == 0
  end

  def title
    resource.main_title
  end

  def curator
    return nil if curator_user_id.nil?
    User.find(curator_user_id)
  end

  def draft_doi
    self.doi ||= if Rails.env.development? && ENV["DATACITE_USER"].blank?
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
    @resource ||= PULDatacite::Resource.new_from_json(metadata)
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

  private

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
      save!
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
end
# rubocop:ensable Metrics/ClassLength
