# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class Work < ApplicationRecord
  # Errors for cases where there is no valid Group
  class InvalidGroupError < ::ArgumentError; end

  has_many :work_activity, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many :user_work, -> { order(updated_at: :desc) }, dependent: :destroy
  has_many :upload_snapshots, -> { order(updated_at: :desc) }, dependent: :destroy

  belongs_to :group, class_name: "Group"
  belongs_to :curator, class_name: "User", foreign_key: "curator_user_id", optional: true

  attribute :work_type, :string, default: "DATASET"
  attribute :profile, :string, default: "DATACITE"

  attr_accessor :user_entered_doi

  alias state_history user_work

  delegate :valid_to_submit, :valid_to_draft, :valid_to_approve, :valid_to_complete, to: :work_validator

  include AASM

  aasm column: :state do
    state :none, initial: true
    state :draft, :awaiting_approval, :approved, :withdrawn, :deletion_marker

    event :draft, after: :draft_doi do
      transitions from: :none, to: :draft, guard: :valid_to_draft
    end

    event :complete_submission do
      transitions from: :draft, to: :awaiting_approval, guard: :valid_to_complete
    end

    event :request_changes do
      transitions from: :awaiting_approval, to: :awaiting_approval, guard: :valid_to_submit
    end

    event :revert_to_draft do
      transitions from: :awaiting_approval, to: :draft, guard: :valid_to_draft
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
      transitions from: :withdrawn, to: :deletion_marker
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
  # * it is being edited by a group admin of the group where is resides
  # * it is being edited by a super admin
  # @param [User]
  # @return [Boolean]
  def editable_by?(user)
    submitted_by?(user) || administered_by?(user)
  end

  def editable_in_current_state?(user)
    # anyone with edit privleges can edit a work while it is in draft
    return editable_by?(user) if draft?

    # Only admisitrators can edit a work in other states
    administered_by?(user)
  end

  def submitted_by?(user)
    created_by_user_id == user.id
  end

  def administered_by?(user)
    user.has_role?(:group_admin, group)
  end

  class << self
    def find_by_doi(doi)
      prefix = "10.34770/"
      doi = "#{prefix}#{doi}" unless doi.blank? || doi.start_with?(prefix)
      Work.find_by!("metadata @> ?", JSON.dump(doi:))
    end

    def find_by_ark(ark)
      prefix = "ark:/"
      ark = "#{prefix}#{ark}" unless ark.blank? || ark.start_with?(prefix)
      Work.find_by!("metadata @> ?", JSON.dump(ark:))
    end

    delegate :resource_type_general_values, to: PDCMetadata::Resource

    def list_embargoed
      Work.where("embargo_date >= current_date").where(state: "approved")
    end

    def list_released_embargo
      Work.where("embargo_date = current_date-1").where(state: "approved")
    end
  end

  include Rails.application.routes.url_helpers

  before_save do |work|
    # Ensure that the metadata JSONB postgres field is persisted properly
    work.metadata = JSON.parse(work.resource.to_json)
  end

  after_save do |work|
    if work.approved?
      work.reload
    end
  end

  validate do |_work|
    work_validator.valid?
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

  def title
    resource.main_title
  end

  def uploads_attributes
    return [] if approved? # once approved we no longer allow the updating of uploads via the application
    uploads.map do |upload|
      {
        id: upload.id,
        key: upload.key,
        filename: upload.filename.to_s,
        created_at: upload.created_at,
        url: upload.url
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
    resource.doi = datacite_service.draft_doi
    save!
  end

  # Return the DOI formatted as a URL, so it can be used as a link on display pages
  # @return [String] A url formatted version of the DOI
  def doi_url
    return "https://doi.org/#{doi}" unless doi.starts_with?("https://doi.org")
    doi
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end

  def resource=(resource)
    @resource = resource
    # Ensure that the metadata JSONB postgres field is persisted properly
    self.metadata = JSON.parse(resource.to_json)
  end

  def resource
    @resource ||= PDCMetadata::Resource.new_from_jsonb(metadata)
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
    WorkActivity.add_work_activity(id, "Unassigned existing curator", current_user.id, activity_type: WorkActivity::SYSTEM)
  end

  def update_curator(curator_user_id, current_user)
    # Update the curator on the Work
    self.curator_user_id = curator_user_id
    save!

    # ...and log the activity
    new_curator = User.find(curator_user_id)

    work_url = "[#{title}](#{Rails.application.routes.url_helpers.work_url(self)})"

    # Troubleshooting https://github.com/pulibrary/pdc_describe/issues/1783
    if work_url.include?("/describe/describe/")
      Rails.logger.error("URL #{work_url} included /describe/describe/ and was fixed. See https://github.com/pulibrary/pdc_describe/issues/1783")
      work_url = work_url.gsub("/describe/describe/", "/describe/")
    end

    message = if curator_user_id.to_i == current_user.id
                "Self-assigned @#{current_user.uid} as curator for work #{work_url}"
              else
                "Set curator to @#{new_curator.uid} for work #{work_url}"
              end
    WorkActivity.add_work_activity(id, message, current_user.id, activity_type: WorkActivity::SYSTEM)
  end

  def add_message(message, current_user_id)
    WorkActivity.add_work_activity(id, message, current_user_id, activity_type: WorkActivity::MESSAGE)
  end

  def add_provenance_note(date, note, current_user_id, change_label = "")
    WorkActivity.add_work_activity(id, { note:, change_label: }.to_json, current_user_id, activity_type: WorkActivity::PROVENANCE_NOTES, created_at: date)
  end

  def log_changes(resource_compare, current_user_id)
    return if resource_compare.identical?
    WorkActivity.add_work_activity(id, resource_compare.differences.to_json, current_user_id, activity_type: WorkActivity::CHANGES)
  end

  def log_file_changes(current_user_id)
    return if changes.count == 0
    WorkActivity.add_work_activity(id, changes.to_json, current_user_id, activity_type: WorkActivity::FILE_CHANGES)
  end

  def activities
    WorkActivity.activities_for_work(id, WorkActivity::MESSAGE_ACTIVITY_TYPES + WorkActivity::CHANGE_LOG_ACTIVITY_TYPES)
  end

  def new_notification_count_for_user(user_id)
    WorkActivityNotification.joins(:work_activity)
                            .where(user_id:, read_at: nil)
                            .where(work_activity: { work_id: id })
                            .count
  end

  # Marks as read the notifications for the given user_id in this work.
  # In practice, the user_id is the id of the current user and therefore this method marks the current's user
  # notifications as read.
  def mark_new_notifications_as_read(user_id)
    # Notice that we fetch and update the information in batches
    # so that we don't issue individual SQL SELECT + SQL UPDATE
    # for each notification.
    #
    # Rails batching information:
    #   https://guides.rubyonrails.org/active_record_querying.html
    #   https://api.rubyonrails.org/classes/ActiveRecord/Batches.html

    # Disable this validation since we want to force a SQL UPDATE.
    # rubocop:disable Rails/SkipsModelValidations
    now_utc = Time.now.utc
    WorkActivityNotification.joins(:work_activity).where("user_id=? and work_id=?", user_id, id).in_batches(of: 1000).update_all(read_at: now_utc)
    # rubocop:enable Rails/SkipsModelValidations
  end

  def current_transition
    aasm.current_event.to_s.humanize.delete("!")
  end

  # Retrieve the S3 file uploads associated with the Work
  # @return [Array<S3File>]
  def uploads
    return post_curation_uploads if approved?

    pre_curation_uploads
  end

  # Retrieve the S3 file uploads named "README"
  # @return [Array<S3File>]
  def readme_uploads
    uploads.select { |s3_file| s3_file.filename.include?("README") }
  end

  # Retrieve the S3 file uploads which are research artifacts proper (not README or other files providing metadata/documentation)
  # @return [Array<S3File>]
  def artifact_uploads
    uploads.reject { |s3_file| s3_file.filename.include?("README") }
  end

  # Returns the list of files for the work with some basic information about each of them.
  # This method is much faster than `uploads` because it does not return the actual S3File
  # objects to the client, instead it returns just a few selected data elements.
  # rubocop:disable Metrics/MethodLength
  def file_list
    start = Time.zone.now
    s3_files = approved? ? post_curation_uploads : pre_curation_uploads
    files_info = s3_files.map do |s3_file|
      {
        "safe_id": s3_file.safe_id,
        "filename": s3_file.filename,
        "filename_display": s3_file.filename_display,
        "last_modified": s3_file.last_modified,
        "last_modified_display": s3_file.last_modified_display,
        "size": s3_file.size,
        "display_size": s3_file.display_size,
        "url": s3_file.url,
        "is_folder": s3_file.is_folder
      }
    end
    log_performance(start, "file_list called for #{id}")
    files_info
  end
  # rubocop:enable Metrics/MethodLength

  def total_file_size
    total_size = 0
    file_list.each do |file|
      total_size += file[:size]
    end
    total_size
  end

  # Calculates the total file size from a given list of files
  # This is so that we don't fetch the list twice from AWS since it can be expensive when
  # there are thousands of files on the work.
  def total_file_size_from_list(files)
    files.sum { |file| file[:size] }
  end

  # Fetches the data from S3 directly bypassing ActiveStorage
  def pre_curation_uploads
    s3_query_service.client_s3_files.sort_by(&:filename)
  end

  # Accesses post-curation S3 Bucket Objects
  def post_curation_s3_resources
    if approved?
      s3_resources
    else
      []
    end
  end

  # Returns the files in post-curation for the work
  def post_curation_uploads(force_post_curation: false)
    if force_post_curation
      # Always use the post-curation data regardless of the work's status
      post_curation_s3_query_service = S3QueryService.new(self, "postcuration")
      post_curation_s3_query_service.data_profile.fetch(:objects, [])
    else
      # Return the list based of files honoring the work status
      post_curation_s3_resources
    end
  end

  def s3_files
    pre_curation_uploads
  end

  def s3_client
    s3_query_service.client
  end

  delegate :bucket_name, :prefix, to: :s3_query_service
  delegate :doi_attribute_url, :curator_or_current_uid, to: :datacite_service

  # Generates the S3 Object key
  # @return [String]
  def s3_object_key
    "#{doi}/#{id}"
  end

  # Transmit a HEAD request for the S3 Bucket directory for this Work
  # @param bucket_name location to be checked to be found
  # @return [Aws::S3::Types::HeadObjectOutput]
  def find_post_curation_s3_dir(bucket_name:)
    # TODO: Directories really do not exists in S3
    #      if we really need this check then we need to do something else to check the bucket
    s3_client.head_object({
                            bucket: bucket_name,
                            key: s3_object_key
                          })
    true
  rescue Aws::S3::Errors::NotFound
    nil
  end

  # Generates the JSON serialized expression of the Work
  # @param args [Array<Hash>]
  # @option args [Boolean] :force_post_curation Force the request of AWS S3
  #   Resources, clearing the in-memory cache
  # @return [String]
  def as_json(*args)
    files = files_as_json(*args)

    # to_json returns a string of serialized JSON.
    # as_json returns the corresponding hash.
    {
      "resource" => resource.as_json,
      "files" => files,
      "group" => group.as_json.except("id"),
      "embargo_date" => embargo_date_as_json,
      "created_at" => format_date_for_solr(created_at),
      "updated_at" => format_date_for_solr(updated_at)
    }
  end

  # Format the date for Apache Solr
  # @param date [ActiveSupport::TimeWithZone]
  # @return [String]
  def format_date_for_solr(date)
    date.strftime("%Y-%m-%dT%H:%M:%SZ")
  end

  def pre_curation_uploads_count
    s3_query_service.file_count
  end

  delegate :ark, :doi, :resource_type, :resource_type=, :resource_type_general, :resource_type_general=,
           :to_xml, to: :resource

  # S3QueryService object associated with this Work
  # @return [S3QueryService]
  def s3_query_service
    mode = approved? ? "postcuration" : "precuration"
    @s3_query_service ||= S3QueryService.new(self, mode)
  end

  def past_snapshots
    UploadSnapshot.where(work: self)
  end

  # Build or find persisted UploadSnapshot models for this Work
  # @param [integer] user_id optional user to assign the snapshot to
  # @return [UploadSnapshot]
  def reload_snapshots(user_id: nil)
    work_changes = []
    s3_files = pre_curation_uploads
    s3_filenames = s3_files.map(&:filename)

    upload_snapshot = latest_snapshot

    upload_snapshot.snapshot_deletions(work_changes, s3_filenames)

    upload_snapshot.snapshot_modifications(work_changes, s3_files)

    # Create WorkActivity models with the set of changes
    unless work_changes.empty?
      new_snapshot = UploadSnapshot.new(work: self, url: s3_query_service.prefix)
      new_snapshot.store_files(s3_files)
      new_snapshot.save!
      WorkActivity.add_work_activity(id, work_changes.to_json, user_id, activity_type: WorkActivity::FILE_CHANGES)
    end
  end

  def self.presenter_class
    WorkPresenter
  end

  def presenter
    self.class.presenter_class.new(work: self)
  end

  def changes
    @changes ||= []
  end

  def track_change(action, filename)
    changes << { action:, filename: }
  end

  # rubocop:disable Naming/PredicateName
  def has_rights?(rights_id)
    resource.rights_many.index { |rights| rights.identifier == rights_id } != nil
  end
  # rubocop:enable Naming/PredicateName

  # This is the solr id / work show page in PDC Discovery
  def pdc_discovery_url
    "https://datacommons.princeton.edu/discovery/catalog/doi-#{doi.tr('/', '-').tr('.', '-')}"
  end

  # Determine whether or not the Work is under active embargo
  # @return [Boolean]
  def embargoed?
    return false if embargo_date.blank?

    current_date = Time.zone.now
    embargo_date >= current_date
  end

  protected

    def work_validator
      @work_validator ||= WorkValidator.new(self)
    end

    # This must be protected, NOT private for ActiveRecord to work properly with this attribute.
    #   Protected will still keep others from setting the metatdata, but allows ActiveRecord the access it needs
    def metadata=(metadata)
      super
      @resource = PDCMetadata::Resource.new_from_jsonb(metadata)
    end

  private

    def publish(user)
      datacite_service.publish_doi(user)
      update_ark_information
      publish_precurated_files(user)
      save!
    end

    # Update EZID (our provider of ARKs) with the new information for this work.
    def update_ark_information
      # We only want to update the ark url under certain conditions.
      # Set this value in config/update_ark_url.yml
      if Rails.configuration.update_ark_url
        if ark.present?
          Ark.update(ark, datacite_service.doi_attribute_url)
        end
      end
    end

    def track_state_change(user, state = aasm.to_state)
      uw = UserWork.new(user_id: user.id, work_id: id, state:)
      uw.save!
      WorkActivity.add_work_activity(id, "marked as #{state.to_s.titleize}", user.id, activity_type: WorkActivity::SYSTEM)
      WorkStateTransitionNotification.new(self, user.id).send
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

    def publish_precurated_files(user)
      # We need to explicitly check the to post-curation bucket here.
      s3_post_curation_query_service = S3QueryService.new(self, "postcuration")

      s3_dir = find_post_curation_s3_dir(bucket_name: s3_post_curation_query_service.bucket_name)
      raise(StandardError, "Attempting to publish a Work with an existing S3 Bucket directory for: #{s3_object_key}") unless s3_dir.nil?

      # Copy the pre-curation S3 Objects to the post-curation S3 Bucket...
      s3_query_service.publish_files(user)
    end

    def latest_snapshot
      return upload_snapshots.first unless upload_snapshots.empty?

      UploadSnapshot.new(work: self, files: [])
    end

    def datacite_service
      @datacite_service ||= PULDatacite.new(self)
    end

    def files_as_json(*args)
      return [] if embargoed?

      force_post_curation = args.any? { |arg| arg[:force_post_curation] == true }

      # Pre-curation files are not accessible externally,
      # so we are not interested in listing them in JSON.
      post_curation_uploads(force_post_curation:).map do |upload|
        {
          "filename": upload.filename,
          "size": upload.size,
          "display_size": upload.display_size,
          "url": upload.globus_url
        }
      end
    end

    def embargo_date_as_json
      if embargo_date.present?
        embargo_datetime = embargo_date.to_datetime
        embargo_date_iso8601 = embargo_datetime.iso8601
        # Apache Solr timestamps require the following format:
        # 1972-05-20T17:33:18Z
        # https://solr.apache.org/guide/solr/latest/indexing-guide/date-formatting-math.html
        embargo_date_iso8601.gsub(/\+.+$/, "Z")
      end
    end

    def log_performance(start, message)
      elapsed = Time.zone.now - start
      if elapsed > 20
        Rails.logger.warn("PERFORMANCE: #{message}. Elapsed: #{elapsed} seconds")
      else
        Rails.logger.info("PERFORMANCE: #{message}. Elapsed: #{elapsed} seconds")
      end
    end
end
# rubocop:enable Metrics/ClassLength
