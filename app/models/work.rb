# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  MAX_UPLOADS = 20

  # Errors for cases where there is no valid Collection
  class InvalidCollectionError < ::ArgumentError; end

  has_many :work_activity, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many :user_work, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many_attached :pre_curation_uploads, service: :amazon_pre_curation

  belongs_to :collection

  attribute :work_type, :string, default: "DATASET"
  attribute :profile, :string, default: "DATACITE"

  attr_accessor :user_entered_doi

  alias state_history user_work

  include AASM

  aasm column: :state do
    state :none, inital: true
    state :draft, :awaiting_approval, :approved, :withdrawn, :tombstone

    event :draft, after: :draft_doi do
      transitions from: :none, to: :draft, guard: :valid_to_draft
    end

    event :complete_submission do
      transitions from: :draft, to: :awaiting_approval, guard: :valid_to_submit, after: :notify_collection_curators
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

  def state=(new_state)
    new_state_sym = new_state.to_sym
    valid_states = self.class.aasm.states.map(&:name)
    raise(StandardError, "Invalid state '#{new_state}'") unless valid_states.include?(new_state_sym)
    aasm_write_state_without_persistence(new_state_sym)
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
    submitted_by?(user) || administered_by?(user)
  end

  def submitted_by?(user)
    created_by_user_id == user.id
  end

  def administered_by?(user)
    user.has_role?(:collection_admin, collection)
  end

  class << self
    def unfinished_works(user, search_terms = nil)
      works = works_by_user_state(user, ["none", "draft", "awaiting_approval"])
      filter_works(works, search_terms)
    end

    def completed_works(user, search_terms = nil)
      works = works_by_user_state(user, "approved")
      filter_works(works, search_terms)
    end

    def withdrawn_works(user, search_terms = nil)
      works = works_by_user_state(user, "withdrawn")
      filter_works(works, search_terms)
    end

    def filter_works(works, search_terms)
      return works if search_terms.nil?
      terms = search_terms.strip.downcase
      works.select { |work| work.match?(terms) }
    end

    def find_by_doi(doi)
      models = all.select { |work| !work.doi.nil? && work.doi.include?(doi) }
      raise ActiveRecord::RecordNotFound if models.empty?
      models.first
    end

    def find_by_ark(ark)
      models = all.select { |work| !work.ark.nil? && work.ark.include?(ark) }
      raise ActiveRecord::RecordNotFound if models.empty?
      models.first
    end

    delegate :resource_type_general_options, to: PDCMetadata::Resource

    # Determines whether or not a test DOI should be referenced
    # (this avoids requests to the DOI API endpoint for non-production deployments)
    # @return [Boolean]
    def publish_test_doi?
      (Rails.env.development? || Rails.env.test?) && Rails.configuration.datacite.user.blank?
    end

    private

      def works_by_user_state(user, state)
        # The user's own works by state (if any)
        works = Work.where(created_by_user_id: user, state: state).to_a

        if user.admin_collections.count > 0
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

        works.uniq(&:id).sort_by(&:updated_at).reverse
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
    work.save_pre_curation_uploads
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

  def curator
    return nil if curator_user_id.nil?
    User.find(curator_user_id)
  end

  def uploads_attributes
    return [] if approved? # once approved we no longer allow the updating of uploads via the application
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
    resource.doi = if self.class.publish_test_doi?
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
    new_curator = User.find(curator_user_id)
    message = if curator_user_id == current_user.id
                "Self-assigned as curator"
              else
                "Set curator to @#{new_curator.uid}"
              end
    WorkActivity.add_system_activity(id, message, current_user.id)
  end

  def curator_or_current_uid(user)
    persisted = if curator.nil?
                  user
                else
                  curator
                end
    persisted.uid
  end

  def add_comment(comment, current_user_id)
    WorkActivity.add_system_activity(id, comment, current_user_id, activity_type: "COMMENT")
  end

  def log_changes(resource_compare, current_user_id)
    return if resource_compare.identical?
    WorkActivity.add_system_activity(id, resource_compare.differences.to_json, current_user_id, activity_type: "CHANGES")
  end

  def log_file_changes(changes, current_user_id)
    return if changes.count == 0
    WorkActivity.add_system_activity(id, changes.to_json, current_user_id, activity_type: "FILE-CHANGES")
  end

  def activities
    WorkActivity.where(work_id: id).sort_by(&:updated_at).reverse
  end

  def changes
    activities.select(&:log_event_type?)
  end

  def comments
    activities.select(&:comment_event_type?)
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

  # This ensures that new ActiveStorage::Attachment objects can be modified before they are persisted
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

  # Transmit a HEAD request for an S3 Object in the post-curation Bucket
  # @param key [String]
  # @param bucket_name [String]
  # @return [Aws::S3::Types::HeadObjectOutput]
  def find_post_curation_s3_object(bucket_name:, key:)
    s3_client.head_object({
                            bucket: bucket_name,
                            key: key
                          })
    true
  rescue Aws::S3::Errors::NotFound
    nil
  end

  # Generates the S3 Object key
  # @return [String]
  def s3_object_key
    "#{doi}/#{id}"
  end

  # Transmit a HEAD request for the S3 Bucket directory for this Work
  # @param bucket_name location to be checked to be found
  # @return [Aws::S3::Types::HeadObjectOutput]
  def find_post_curation_s3_dir(bucket_name:)
    s3_client.head_object({
                            bucket: bucket_name,
                            key: s3_object_key
                          })
    true
  rescue Aws::S3::Errors::NotFound
    nil
  end

  # Transmit a DELETE request for the S3 directory in the pre-curation Bucket
  # @return [Aws::S3::Types::DeleteObjectOutput]
  def delete_pre_curation_s3_dir
    s3_client.delete_object({
                              bucket: bucket_name,
                              key: s3_object_key
                            })
  rescue Aws::S3::Errors::ServiceError => error
    raise(StandardError, "Failed to delete the pre-curation S3 Bucket directory #{s3_object_key}: #{error}")
  end

  # This is invoked within the scope of #after_save. Attachment objects require that the parent record be persisted (hence, #before_save is not an option).
  # However, a consequence of this is that #after_save is invoked whenever a new attached Blob or Attachment object is persisted.
  def attach_s3_resources
    return if approved?
    changes = []
    # This retrieves and adds S3 uploads if they do not exist
    pre_curation_s3_resources.each do |s3_file|
      if add_pre_curation_s3_object(s3_file)
        changes << { action: :added, filename: s3_file.filename }
      end
    end

    # Log the new files, but don't link the change to the current_user since we really don't know
    # who added the files directly to AWS S3.
    log_file_changes(changes, nil)
  end

  # Returns true if the work matches the search terms. It searches inside
  # the resource, the curator, and the work fields.
  # Uses a brute-force approach to search for the value.
  # A more fine tuned version could be developed to search within certain specific fields.
  def match?(search_terms)
    return true if resource && resource.to_json.downcase.include?(search_terms)
    return true if curator && curator.to_json.downcase.include?(search_terms)
    return true if to_json.downcase.include?(search_terms)
    false
  end

  delegate :ark, :doi, :resource_type, :resource_type=, :resource_type_general, :resource_type_general=,
           :to_xml, :to_json, to: :resource

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

    def publish(user)
      publish_doi(user)
      update_ark_information
      publish_precurated_files
      save!
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

    # Generates the key for ActiveStorage::Attachment and Attachment::Blob objects
    # @param attachment [ActiveStorage::Attachment]
    # @return [String]
    def generate_attachment_key(attachment)
      attachment_filename = attachment.filename.to_s
      attachment_key = attachment.key

      # Files actually coming from S3 include the DOI and bucket as part of the file name
      #  Files being attached in another manner may not have it, so we should include it.
      #  This is really for testing only.
      key_base = "#{doi}/#{id}"
      attachment_key = [key_base, attachment_filename].join("/") unless attachment_key.include?(key_base)

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

    # rubocop:disable Metrics/AbcSize
    def validate_metadata
      return if metadata.blank?
      errors.add(:base, "Must provide a title") if resource.main_title.blank?
      errors.add(:base, "Must provide a description") if resource.description.blank?
      errors.add(:base, "Must indicate the Publisher") if resource.publisher.blank?
      errors.add(:base, "Must indicate the Publication Year") if resource.publication_year.blank?
      errors.add(:base, "Must indicate a Rights statement") if resource.rights.nil?
      errors.add(:base, "Must provide a Version number") if resource.version_number.blank?
      validate_creators
      validate_related_objects
    end
    # rubocop:enable Metrics/AbcSize

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

    def validate_related_objects
      return if resource.related_objects.empty?
      invalid = resource.related_objects.reject(&:valid?)
      errors.add(:base, "Related Objects are invalid: #{invalid.map(&:errors).join(', ')}") if invalid.count.positive?
    end

    def publish_doi(user)
      return Rails.logger.info("Publishing hard-coded test DOI during development.") if self.class.publish_test_doi?

      if doi.starts_with?(Rails.configuration.datacite.prefix)
        result = data_cite_connection.update(id: doi, attributes: doi_attributes)
        if result.failure?
          resolved_user = curator_or_current_uid(user)
          message = "@#{resolved_user} Error publishing DOI. #{result.failure.status} / #{result.failure.reason_phrase}"
          WorkActivity.add_system_activity(id, message, user.id, activity_type: "DATACITE_ERROR")
        end
      elsif ark.blank? # we can not update the url anywhere
        Honeybadger.notify("Publishing for a DOI we do not own and no ARK is present: #{doi}")
      end
    end

    def doi_attribute_url
      "https://datacommons.princeton.edu/discovery/doi/#{doi}"
    end

    def doi_attribute_resource
      PDCMetadata::Resource.new_from_json(metadata)
    end

    def doi_attribute_xml
      unencoded = doi_attribute_resource.to_xml
      Base64.encode64(unencoded)
    end

    def doi_attributes
      {
        "event" => "publish",
        "xml" => doi_attribute_xml,
        "url" => doi_attribute_url
      }
    end

    def validate_uploads
      # The number of pre-curation uploads should be validated, as these are mutated directly
      if pre_curation_uploads.length > MAX_UPLOADS
        errors.add(:base, "Only #{MAX_UPLOADS} files may be uploaded by a user to a given Work. #{pre_curation_uploads.length} files were uploaded for the Work: #{ark}")
      end
    end

    # This needs to be called #before_save
    # This ensures that new ActiveStorage::Attachment objects are persisted with custom keys (which are generated from the file name and DOI)
    # @param new_attachments [Array<ActiveStorage::Attachment>]
    def save_new_attachments(new_attachments:)
      new_attachments.each do |attachment|
        # There are cases (race conditions?) where the ActiveStorage::Blob objects are not persisted
        next if attachment.frozen?

        # This ensures that the custom key for the ActiveStorage::Attachment and ActiveStorage::Blob objects are generated
        generated_key = generate_attachment_key(attachment)
        attachment.blob.key = generated_key
        attachment.blob.save

        attachment.save
      end
    end

    # S3QueryService object associated with this Work
    # @return [S3QueryService]
    def s3_query_service
      @s3_query_service = S3QueryService.new(self, !approved?)
    end

    # Request S3 Bucket Objects associated with this Work
    # @return [Array<S3File>]
    def s3_resources
      data_profile = s3_query_service.data_profile
      data_profile.fetch(:objects, [])
    end
    alias pre_curation_s3_resources s3_resources

    def s3_object_persisted?(s3_file)
      uploads_keys = uploads.map(&:key)
      uploads_keys.include?(s3_file.key)
    end

    def add_pre_curation_s3_object(s3_file)
      return if s3_object_persisted?(s3_file)

      persisted = s3_file_to_blob(s3_file)
      pre_curation_uploads.attach(persisted)
    end

    def publish_precurated_files
      # An error is raised if there are no files to be moved
      raise(StandardError, "Attempting to publish a Work without attached uploads for #{s3_object_key}") if pre_curation_uploads.empty? && post_curation_uploads.empty?

      # We need to explicitly access to post-curation services here.
      # Lets explicitly create it so the state of the work does not have any impact.
      s3_post_curation_query_service = S3QueryService.new(self, false)

      s3_dir = find_post_curation_s3_dir(bucket_name: s3_post_curation_query_service.bucket_name)
      raise(StandardError, "Attempting to publish a Work with an existing S3 Bucket directory for: #{s3_object_key}") unless s3_dir.nil?

      # Copy the pre-curation S3 Objects to the post-curation S3 Bucket...
      transferred_files = s3_post_curation_query_service.publish_files

      # ...check that the files are indeed now in the post-curation bucket...
      pre_curation_uploads.each do |attachment|
        s3_object = find_post_curation_s3_object(bucket_name: s3_post_curation_query_service.bucket_name, key: attachment.key)
        raise(StandardError, "Failed to validate the uploaded S3 Object #{attachment.key}") if s3_object.nil?
      end

      # ...and delete them from the pre-curation bucket.
      transferred_files.each(&:purge)
      delete_pre_curation_s3_dir
    end

    def notify_collection_curators(current_user)
      curators = collection.administrators.map { |admin| "@#{admin.uid}" }.join(", ")
      notification = "#{curators} The [work](#{work_url(self)}) is ready for review."
      WorkActivity.add_system_activity(id, notification, current_user.id)
    end
end
# rubocop:ensable Metrics/ClassLength
