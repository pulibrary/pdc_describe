# frozen_string_literal: true
class WorkMigrationController < ApplicationController
  def migrate
    work = Work.find(params[:id])
    if work.ark.present? && current_user.can_admin?(work.group)
      begin
        run_migration(work)
      rescue RuntimeError => e
        flash[:notice] = e.message
      end
    elsif !current_user.can_admin?(work.group)
      flash[:notice] = "Unauthorized migration"
      Honeybadger.notify("Unauthorized to migration work #{work.id} (current user: #{current_user.id})")
    else
      flash[:notice] = "The ark is blank, no migration from Dataspace is possible"
    end
    redirect_to work_path(work)
  end

  private

    def run_migration(work)
      dspace = PULDspaceMigrate.new(work)
      dspace.migrate
      flash[:notice] = dspace.migration_message
      WorkActivity.add_work_activity(work.id, { migration_id: dspace.migration_snapshot.id,
                                                message: dspace.migration_message, file_count: dspace.file_keys.count,
                                                directory_count: dspace.directory_keys.count }.to_json,
                                     current_user.id, activity_type: WorkActivity::MIGRATION_START)
    end
end
