# frozen_string_literal: true
class ApprovedUploadSnapshot < BackgroundUploadSnapshot
  def finalize_upload
    new_files.each do |file|
      work.track_change(:added, file["filename"])
    end
    WorkActivity.add_work_activity(work.id, "#{new_files.count} #{'file'.pluralize(new_files.count)} were moved to the post curation bucket", new_files.first["user_id"],
                                   activity_type: WorkActivity::SYSTEM)
  end

  def store_files(s3_files, current_user: nil)
    save # needed so I can reuse the code in backroundUploadSnapshot
    self.files = s3_files.map do |file|
      { "filename" => file.filename, "checksum" => file.checksum,
        "upload_status" => "started", user_id: current_user&.id, snapshot_id: id }
    end
  end
end
