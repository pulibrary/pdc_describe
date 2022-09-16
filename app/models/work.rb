# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  MAX_UPLOADS = 20

  has_many :work_activity, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many_attached :pre_curation_uploads, service: :amazon_pre_curation

  belongs_to :collection

  attribute :work_type, :string, default: "DATASET"
  attribute :profile, :string, default: "DATACITE"

  attr_accessor :user_entered_doi

  validates_with Validators::WorkValidator

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
      transitions from: :awaiting_approval, to: :approved, guard: :valid_to_approve, after: :publish
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

  ##
  # Is this work editable by a given user?
  # A work is editable when:
  # * it is being edited by the person who made it
  # * it is being edited by a collection admin of the collection where is resides
  # * it is being edited by a super admin
  # @param [User]
  # @return [Boolean]
  def editable_by?(user)
    return true if created_by_user_id == user.id
    collection = Collection.find(collection_id)
    return true if user.has_role?(:collection_admin, collection)
    false
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
  end

  after_save do |work|
    if work.approved?
      work.attach_s3_resources if !work.pre_curation_uploads.empty? && work.pre_curation_uploads.length > work.post_curation_uploads.length
      work.reload
    end
  end

  validate do |work|
    if none?
      work.validate_doi
    elsif draft?
      work.valid_to_draft
    else
      work.valid_to_submit
    end
  end

  def attaching_s3_objects?
    @attaching_s3_objects ||= false
  end

  # Overload ActiveRecord.reload method
  # https://apidock.com/rails/ActiveRecord/Base/reload
  #
  # NOTE: Usually `after_save` is a better place to put this kind of code:
  #
  #   after_save do |work|
  #     work.resource = nil
  #   end
  #
  # but that does not work in this case because the block points to a different
  # memory object for `work` than the we want we want to reload.
  def reload(options = nil)
    super
    # Force `resource` to be reloaded
    @resource = nil
    self
  end

  def validate_doi
    return true unless user_entered_doi
    if /^10.\d{4,9}\/[-._;()\/:a-z0-9\-]+$/.match?(doi.downcase)
      response = Faraday.get("#{Rails.configuration.datacite.doi_url}#{doi}")
      errors.add(:base, "Invalid DOI: can not verify it's authenticity") unless response.success? || response.status == 302
    else
      errors.add(:base, "Invalid DOI: does not match format")
    end
    errors.count == 0
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
    validate_uploads
    errors.count == 0
  end

  def valid_to_approve(user)
    valid_to_submit
    unless user.has_role? :collection_admin, collection
      errors.add :base, "Unauthorized to Approve"
    end
    errors.count == 0
  end

  def title
    resource.main_title
  end

  def doi
    resource.doi
  end

  def ark
    resource.ark
  end

  def curator
    return nil if curator_user_id.nil?
    User.find(curator_user_id)
  end

  def to_xml
    resource.to_xml
  end

  def to_json
    resource.to_json
  end

  def uploads_attributes
    uploads.map do |upload|
      {
        id: upload.id,
        key: upload.key,
        filename: upload.filename.to_s,
        created_at: upload.created_at,
        url: rails_blob_path(upload, disposition: "attachment")
      }
    end
  end

  def form_attributes
    {
      uploads: uploads_attributes
    }
  end

  def draft_doi
    return if resource.doi.present?
    resource.doi = if Rails.env.development? && Rails.configuration.datacite.user.blank?
                     Rails.logger.info "Using hard-coded test DOI during development."
                     "10.34770/tbd"
                   else
                     result = data_cite_connection.autogenerate_doi(prefix: Rails.configuration.datacite.prefix)
                     if result.success?
                       result.success.doi
                     else
                       raise("Error generating DOI. #{result.failure.status} / #{result.failure.reason_phrase}")
                     end
                   end
    save!
  end

  def state_history
    UserWork.where(work_id: id).order(updated_at: :desc)
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def resource=(resource)
    @resource = resource
    self.metadata = resource.to_json
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

  def uploads
    return post_curation_uploads if approved?

    pre_curation_uploads
  end

  def save_pre_curation_uploads
    return if pre_curation_uploads.empty?

    new_attachments = pre_curation_uploads.reject(&:persisted?)
    return if new_attachments.empty?

    save_new_attachments(new_attachments: new_attachments)
  end

  # Accesses post-curation S3 Bucket Objects
  def post_curation_s3_resources
    return [] unless approved?

    s3_resources
  end
  alias post_curation_uploads post_curation_s3_resources

  def s3_client
    s3_query_service.client
  end

  delegate :bucket_name, to: :s3_query_service

  def pre_curation_bucket_name
    pre_curation_s3_query_service.bucket_name
  end

  def post_curation_bucket_name
    post_curation_s3_query_service.bucket_name
  end

  def delete_post_curation_uploads(uploads:)
    uploads.each do |upload|
      s3_client.delete_object(bucket: bucket_name, key: upload.key)
    end
  end

  def add_post_curation_s3_object(blob:)
    s3_client.put_object({
                           bucket: post_curation_bucket_name,
                           key: blob.key,
                           body: blob.download
                         })
  end

  # This is invoked within the scope of #after_save. Attachment objects require that the parent record be persisted (hence, #before_save is not an option).
  # However, a consequence of this is that #after_save is invoked whenever a new attached Blob or Attachment object is persisted.
  # @attaching_s3_objects is used to ensure that this is not invoked recursively.
  def attach_s3_resources
    @attaching_s3_objects = true

    if approved?
      # This migrates pre-curation S3 Objects to the post-curation S3 Bucket
      transferred = []
      pre_curation_uploads.each do |attachment|
        unless post_curation_s3_file?(filename: attachment.filename.to_s)
          add_post_curation_s3_object(blob: attachment.blob)
          transferred << attachment
        end
      end

      # There was a race-condition when I attempted the above
      transferred.each(&:purge)
    else
      # This retrieves and adds S3 uploads if they do not exist
      pre_curation_s3_resources.each do |s3_file|
        add_pre_curation_s3_object(s3_file)
      end
    end
    @attaching_s3_objects = false
  end

  protected

    # This must be protected, NOT private for ActiveRecord to work properly with this attribute.
    #   Protected will still keep others from setting the metatdata, but allows ActiveRecord the access it needs
    def metadata=(metadata)
      super
      @resource = PDCMetadata::Resource.new_from_json(metadata)
    end

  private

    def s3_file_to_blob(s3_file)
      existing_blob = ActiveStorage::Blob.find_by(key: s3_file.filename)

      if existing_blob.present?
        Rails.logger.warn("There is a blob existing for #{s3_file.filename}, which we are not expecting!  It will be reattached #{existing_blob.inspect}")
        return existing_blob
      end

      params = { filename: s3_file.filename, content_type: "", byte_size: s3_file.size, checksum: s3_file.checksum }
      blob = ActiveStorage::Blob.create_before_direct_upload!(**params)
      blob.key = s3_file.filename
      blob
    end

    def post_curation_s3_file?(filename:)
      post_curation_uploads_keys = post_curation_uploads.map(&:filename)
      post_curation_uploads_keys.include?(filename)
    end

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
      @data_cite_connection ||= Datacite::Client.new(username: Rails.configuration.datacite.user,
                                                     password: Rails.configuration.datacite.password,
                                                     host: Rails.configuration.datacite.host)
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
      errors.add(:base, "Must indicate a Rights statement") if resource.rights.nil?
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
      if Rails.env.development? && Rails.configuration.datacite.user.blank?
        Rails.logger.info "Publishing hard-coded test DOI during development."
      elsif doi.starts_with?(Rails.configuration.datacite.prefix)
        result = data_cite_connection.update(id: doi, attributes: doi_attributes)
        if result.failure?
          message = "@#{curator_or_current_uid(user)} Error publishing DOI. #{result.failure.status} / #{result.failure.reason_phrase}"
          WorkActivity.add_system_activity(id, message, user.id, activity_type: "DATACITE_ERROR")
        end
      elsif ark.blank? # we can not update the url anywhere
        Honeybadger.notify("Publishing for a DOI we do not own and no ARK is present: #{doi}")
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
        "xml" => Base64.encode64(PDCMetadata::Resource.new_from_json(metadata).to_xml),
        "url" => "https://datacommons.princeton.edu/discovery/" # TODO: this should be a link to the item in PDC-discovery
      }
    end

    def validate_uploads
      # The number of pre-curation uploads should be validated, as these are mutated directly
      if pre_curation_uploads.length > MAX_UPLOADS
        errors.add(:base, "Only #{MAX_UPLOADS} files may be uploaded by a user to a given Work. #{pre_curation_uploads.length} files were uploaded for the Work: #{ark}")
      end
    end

    # This needs to be called #before_save
    def save_new_attachments(new_attachments:)
      new_attachments.each do |attachment|
        generated_key = generate_attachment_key(attachment)
        attachment.blob.key = generated_key
        attachment.blob.save

        attachment.save
      end
    end

    def pre_curation_s3_query_service
      @pre_curation_s3_query_service ||= S3QueryService.new(self, true)
    end

    def post_curation_s3_query_service
      @post_curation_s3_query_service ||= S3QueryService.new(self, false)
    end

    def s3_query_service
      if approved?
        post_curation_s3_query_service
      else
        pre_curation_s3_query_service
      end
    end

    # @return [Array<S3File>]
    def s3_resources
      data_profile = s3_query_service.data_profile
      data_profile.fetch(:objects, [])
    end
    alias pre_curation_s3_resources s3_resources

    def s3_object_persisted?(s3_file)
      uploads_filenames = uploads.map(&:filename)

      persisted_filenames = uploads_filenames.select { |filename| filename.to_s == s3_file.filename }
      !persisted_filenames.empty?
    end

    def add_pre_curation_s3_object(s3_file)
      return if s3_object_persisted?(s3_file)

      persisted = s3_file_to_blob(s3_file)
      pre_curation_uploads.attach(persisted)
    end
end
# rubocop:ensable Metrics/ClassLength
