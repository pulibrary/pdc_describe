class UploadSnapshotFiles < ActiveRecord::Migration[6.1]
  def up
    # Add column to store converted data
    add_column :upload_snapshots, :files, 'jsonb'

    # migrate any filename and checksum to the new jsonb format
    UploadSnapshot.all.each do |snapshot|
      snapshot.files = [{filename: snapshot.filename, checksum: snapshot.checksum}]
      snapshot.save!
    end

    # Remove old columns
    remove_column :upload_snapshots, :filename
    remove_column :upload_snapshots, :checksum
  end

  # Reversed steps does allow for migration rollback
  def down
    add_column :upload_snapshots, :filename, :string
    add_column :upload_snapshots, :checksum, :string

      # migrate any files to the old filename and checksum format
      UploadSnapshot.all.each do |snapshot|
        snapshot.filename = snapshot.files.first[:filename]
        snapshot.checksum = snapshot.files.first[:checksum]
        snapshot.save!
      end
    
      remove_column :upload_snapshots, :files
  end
end
