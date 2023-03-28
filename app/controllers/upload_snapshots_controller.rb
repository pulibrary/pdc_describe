# frozen_string_literal: true
class UploadSnapshotsController < ApplicationController
  # POST /upload-snapshots/:work_id/:uri
  # Here the URI specifies the specific upload for which the snapshot is being generated
  def create
    @upload = find_upload(key: key_param)
    @upload_snapshot = @upload.create_snapshot

    flash[:notice] = "Successfully created the snapshot for upload #{@upload_snapshot.key} attached to work #{work.id}."
    redirect_to edit_upload_snapshot_path(@work)
  rescue StandardError => error
    error_message = "Failed to create the upload snapshot: #{error}"
    Rails.logger.error(error_message)
    flash[:notice] = error_message

    response_location = if @work.nil?
                          works_path
                        else
                          edit_upload_snapshot_path(@work)
                        end

    redirect_to response_location
  end

  def edit
    @uploads = work.uploads

    render :edit
  end

  # DELETE /upload-snapshots/:id
  # Destroys the snapshot after resolving it from the database ID
  def destroy
    current_work = upload_snapshot.work
    upload_snapshot.destroy
    flash[:notice] = "Successfully deleted the upload snapshot #{upload_snapshot_id}."

    redirect_to edit_upload_snapshot_path(current_work)
  rescue StandardError => error
    error_message = "Failed to delete the upload snapshot: #{error}"
    Rails.logger.error(error_message)
    flash[:notice] = error_message

    redirect_to works_path
  end

  def download
    @work = upload_snapshot.work
    if current_user && @work.editable_by?(current_user)
      filename = upload_snapshot.filename
      pre_curation = !@work.approved?
      service = S3QueryService.new(@work, pre_curation)
      redirect_to service.file_url(filename)
    else
      Honeybadger.notify("Can not download work: #{work.id} is not editable by #{current_user}")
      redirect_to root_path, notice: I18n.t("works.download.privs")
    end
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

    def key_param
      @key_param = params[:key]
      raise(ArgumentError, "No URI provided for the file upload.") unless @key_param

      @key_param
    end

    def work
      @work ||= Work.find(work_id)
    end

    def find_upload(key:)
      work.uploads.find { |s3_file| key.include?(s3_file.key) }
    end
end
