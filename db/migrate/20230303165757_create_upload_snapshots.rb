# frozen_string_literal: true
class CreateUploadSnapshots < ActiveRecord::Migration[6.1]
  def change
    create_table :upload_snapshots do |t|
      t.string :filename
      t.string :url
      t.bigint :version
      t.string :checksum
      t.references :work, work: true, null: false, foreign_key: true

      t.timestamps
    end
  end
end
