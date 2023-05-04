class SnapshotUri < ActiveRecord::Migration[6.1]
  def change
    unless column_exists? :upload_snapshots, :url
      rename_column :upload_snapshots, :uri, :url
    end

    unless column_exists? :upload_snapshots, :filename
      add_column :upload_snapshots, :filename, :string
    end

    unless column_exists? :upload_snapshots, :version
      add_column :upload_snapshots, :version, :bigint
    end

    unless column_exists? :upload_snapshots, :checksum
      add_column :upload_snapshots, :checksum, :string
    end
  end
end
