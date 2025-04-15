# frozen_string_literal: true
class WorkDownloaderController < ApplicationController
  def download
    work = Work.find(params[:id])
    if current_user && work.editable_by?(current_user)
      file_name = params[:filename]
      service = S3QueryService.new(work, work.files_bucket_name)
      uri = service.file_url(file_name)
      redirect_to uri
    else
      Honeybadger.notify("Can not download work: #{work.id} is not editable by #{current_user.uid}")
      redirect_to root_path, notice: I18n.t("works.download.privs")
    end
  end
end
