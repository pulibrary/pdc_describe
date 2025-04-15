# frozen_string_literal: true
class EmbargoReleaseSnapshot < BackgroundUploadSnapshot
  def finalize_upload
    new_files.each do |file|
      work.track_change(:added, file["filename"])
    end
    WorkActivity.add_work_activity(work.id, "#{new_files.count} #{'file'.pluralize(new_files.count)} were released from embargo to the post-curation bucket", nil,
                                   activity_type: WorkActivity::SYSTEM)
  end

  def store_files(s3_files)
    save # allow out id to be set
    self.files = s3_files.map do |file|
      { "filename" => file.filename, "checksum" => file.checksum, "upload_status" => "started", snapshot_id: id }
    end
  end
end
