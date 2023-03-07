# frozen_string_literal: true
class UploadSnapshotsController < ApplicationController
  # POST /upload-snapshots/:work_id
  def create
    @upload_snapshot = upload.create_snapshot
    flash[:notice] = "Successfully created the upload snapshot #{@upload_snapshot.uri} for work #{work.id}."
    redirect_to work_path(work)
  rescue StandardError => error
    error_message = "Failed to create the upload snapshot: #{error}"
    Rails.logger.error(error_message)
    flash[:notice] = error_message

    redirect_to works_path
  end

  # DELETE /upload-snapshots/:id
  def destroy
    current_work = upload_snapshot.work
    upload_snapshot_uri = upload_snapshot.uri
    upload_snapshot.destroy
    flash[:notice] = "Successfully deleted the upload snapshot #{upload_snapshot_uri}."

    redirect_to work_path(current_work)
  rescue StandardError => error
    error_message = "Failed to delete the upload snapshot: #{error}"
    Rails.logger.error(error_message)
    flash[:notice] = error_message

    redirect_to works_path
  end

  private

    def upload_snapshot_id
      @upload_snapshot_id = params[:id]
      raise(ArgumentError, "No ID provided for the upload snapshot.") unless @upload_snapshot_id

      @upload_snapshot_id
    end

    def upload_snapshot
      return unless upload_snapshot_id

      @upload_snapshot ||= UploadSnapshot.find(upload_snapshot_id)
    end

    def work_id
      @work_id = params[:work_id]
      raise(ArgumentError, "No ID provided for the work.") unless @work_id

      @work_id
    end

    def uri
      @uri = params[:uri]
      raise(ArgumentError, "No URI provided for the file upload.") unless @uri

      @uri
    end

    def work
      @work ||= Work.find(work_id)
    end

    def upload
      work.uploads.find { |s3_file| uri.include?(s3_file.url) }
    end
end
