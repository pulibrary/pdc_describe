# frozen_string_literal: true
class EmbargoUploadSnapshot < BackgroundUploadSnapshot
  def finalize_upload
    new_files.each do |file|
      work.track_change(:added, file["filename"])
    end
    WorkActivity.add_work_activity(work.id, "#{new_files.count} #{'file'.pluralize(new_files.count)} were moved to the embargo bucket", new_files.first["user_id"],
                                   activity_type: WorkActivity::EMBARGO)
  end

  def store_files(s3_files, current_user: nil)
    save # allow out id to be set
    self.files = s3_files.map do |file|
      { "filename" => file.filename, "checksum" => file.checksum,
        "upload_status" => "started", user_id: current_user&.id, snapshot_id: id }
    end
  end
end
