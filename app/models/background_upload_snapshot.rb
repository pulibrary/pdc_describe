# frozen_string_literal: true
class BackgroundUploadSnapshot < UploadSnapshot
  def store_files(uploaded_files, pre_existing_files: [], current_user: nil)
    save # needed so I can point to this snapshot in the files to distinguish new files from existing ones froma past snapshot

    raise(ArgumentError, "Failed to resolve the user ID from #{self}") if current_user.nil?
    user_id = current_user&.id
    self.files = uploaded_files.map do |file|
      { "filename" => prefix_filename(file.original_filename),
        "upload_status" => "started", user_id:, snapshot_id: id }
    end
    files.concat pre_existing_files if pre_existing_files.present?
  end

  def mark_complete(filename, checksum)
    index = files.index { |file| file["filename"] == prefix_filename(filename) }
    if index.nil?
      Rails.logger.error("Uploaded a file that was not part of the orginal Upload: #{id} for work #{work_id}: #{filename}")
      Honeybadger.notify("Uploaded a file that was not part of the orginal Upload: #{id} for work #{work_id}: #{filename}")
    else
      files[index]["upload_status"] = "complete"
      files[index]["checksum"] = checksum
    end
    finalize_upload if upload_complete?
    save
  end

  def upload_complete?
    files.select { |file| file.keys.include?("upload_status") }.map { |file| file["upload_status"] }.uniq == ["complete"]
  end

  def existing_files
    super.select { |file| file["upload_status"].nil? || file["upload_status"] == "complete" }
  end

  def new_files
    files.select { |file| file["snapshot_id"] == id }
  end

  def finalize_upload
    new_files.each do |file|
      work.track_change(:added, file["filename"])
    end

    raise(ArgumentError, "Upload failed with empty files.") if new_files.empty?
    first_new_file = new_files.first

    user_id = first_new_file["user_id"]
    raise(ArgumentError, "Failed to resolve the user ID from #{first_new_file['filename']}") if user_id.nil?

    work.log_file_changes(user_id)
  end

  def prefix_filename(filename)
    if filename.include?(work.prefix)
      filename
    else
      "#{work.prefix}#{filename}"
    end
  end
end
