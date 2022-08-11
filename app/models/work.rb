# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  has_many :work_activity, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many_attached :deposit_uploads

  class << self
    def create_skeleton(title, user_id, collection_id, work_type, profile)
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
    def create_dataset(title, user_id, collection_id, datacite_resource = nil, ark = nil)
      datacite_resource = PULDatacite::Resource.new(title: title) if datacite_resource.nil?
      work = default_work(title, user_id, collection_id, datacite_resource, ark)
      work.draft_doi

      # We skip the validation since we don't have all the required fields yet
      work.save!(validate: false)
      work
    end

    def unfinished_works(user)
      works_by_user_state(user, "AWAITING-APPROVAL")
    end

    def completed_works(user)
      works_by_user_state(user, "APPROVED")
    end

    def withdrawn_works(user)
      works_by_user_state(user, "WITHDRAWN")
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

      def default_work(title, user_id, collection_id, datacite_resource, ark)
        Work.new(
          title: title,
          created_by_user_id: user_id,
          collection_id: collection_id,
          work_type: "DATASET",
          state: "AWAITING-APPROVAL",
          profile: "DATACITE",
          doi: nil,
          data_cite: datacite_resource.to_json,
          ark: ark
        )
      end
  end

  include Rails.application.routes.url_helpers

  belongs_to :collection

  before_save do |work|
    # Ensure that the metadata JSON is persisted properly
    if work.dublin_core.present?
      work.dublin_core = work.dublin_core.to_json
    elsif work.profile == "DATACITE" && work.ark.blank?
      work.ark = Ark.mint
    end

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
    if work.ark.present?
      work.errors.add(:base, "Invalid ARK provided for the Work: #{work.ark}") unless Ark.valid?(work.ark)
    end

    if work.data_cite.present?
      work.errors.add(:base, "Must provide a title") if work.title.blank?
      work.errors.add(:base, "Must provide a description") if work.datacite_resource.description.blank?
      work.errors.add(:base, "Must indicate the Publisher") if work.datacite_resource.publisher.blank?
      work.errors.add(:base, "Must indicate the Publication Year") if work.datacite_resource.publication_year.blank?
      if work.datacite_resource.creators.count == 0
        work.errors.add(:base, "Must provide at least one Creator")
      else
        work.datacite_resource.creators.each do |creator|
          if creator.orcid.present? && Orcid.invalid?(creator.orcid)
            work.errors.add(:base, "ORCID for creator #{creator.value} is not in format 0000-0000-0000-0000")
          end
        end
      end
    end

    if work.deposit_uploads.length > 20
      work.errors.add(:base, "Only 20 files may be uploaded by a user to a given Work. #{work.deposit_uploads.length} files were uploaded for the Work: #{work.ark}")
    end
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
    count = 0
    activities.each do |activity|
      count += WorkActivityNotification.where(user_id: user_id, work_activity_id: activity.id, read_at: nil).count
    end
    count
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

    def track_state_change(user, state)
      uw = UserWork.new(user_id: user.id, work_id: id, state: state)
      uw.save!
      WorkActivity.add_system_activity(id, "marked as #{state}", user.id)
    end

    def data_cite_connection
      @data_cite_connection ||= Datacite::Client.new(username: ENV["DATACITE_USER"],
                                                     password: ENV["DATACITE_PASSWORD"],
                                                     host: ENV["DATACITE_HOST"])
    end
end
# rubocop:ensable Metrics/ClassLength
