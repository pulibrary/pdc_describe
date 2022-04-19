# frozen_string_literal: true

class Work < ApplicationRecord
  belongs_to :collection

  def self.create_skeleton(title, user_id, collection_id, work_type)
    work = Work.new(
      title: title,
      created_by_user_id: user_id,
      collection_id: collection_id,
      work_type: work_type,
      state: "AWAITING-APPROVAL"
    )
    work.save!
    work
  end

  def dataset?
    work_type == "DATASET"
  end

  def etd?
    work_type == "ETD"
  end

  def dataset_id
    Dataset.where(work_id: id).first&.id
  end

  def approve
    self.state = "APPROVED"
    save!
  end

  def withdraw
    self.state = "WITHDRAWN"
    save!
  end

  def resubmit
    self.state = "AWAITING-APPROVAL"
    save!
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
