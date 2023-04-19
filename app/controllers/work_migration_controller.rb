# frozen_string_literal: true
class WorkMigrationController < ApplicationController
  def migrate
    work = Work.find(params[:id])
    if work.ark.present? && current_user.can_admin?(work.group)
      dspace = PULDspaceData.new(work)
      dspace.migrate
      flash[:notice] = dspace.migration_message
      # TODO: Add in WorkActivity here since we know the use information here
    elsif !current_user.can_admin?(work.group)
      flash[:notice] = "Unauthorized migration"
      Honeybadger.notify("Unauthorized to migration work #{work.id} (current user: #{current_user.id})")
    else
      flash[:notice] = "The ark is blank, no migration from Dataspace is possible"
    end
    redirect_to work_path(work)
    # TODO: migrate the work content if the user is allowed and the work has an ark and is migrated
  end
end
