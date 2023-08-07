class AddTypeToUploadSnapshot < ActiveRecord::Migration[6.1]
  def up
    add_column :upload_snapshots, :type, 'string'
    UploadSnapshot.all.each do |upload_snapshot|
      if upload_snapshot.files.count == 0 || upload_snapshot.files.first["migrate_status"].blank?
        upload_snapshot.type = "UploadSnapshot"
      else
        upload_snapshot.type = "MigrationUploadSnapshot"
      end
      upload_snapshot.save
    end
  end
  def down
    remove_column :upload_snapshots, :type, 'string'
  end
end
