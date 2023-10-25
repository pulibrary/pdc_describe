class ProvenanceNoteFormat < ActiveRecord::Migration[6.1]
  def change
    WorkActivity.where(activity_type: WorkActivity::PROVENANCE_NOTES).each do |note|
      unless note.message.starts_with?("{\"note\":")
        note.message = { note: note.message, change_label: "" }.to_json
        note.save
      end
    end
  end
end
