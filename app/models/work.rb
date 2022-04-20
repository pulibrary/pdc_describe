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

  def dataset_id
    Dataset.where(work_id: id).first&.id
  end

  def approve(user)
    self.state = "APPROVED"
    save!
    track_state_change(user, "APPROVED")
  end

  def withdraw(user)
    self.state = "WITHDRAWN"
    save!
    track_state_change(user, "WITHDRAWN")
  end

  def resubmit(user)
    self.state = "AWAITING-APPROVAL"
    save!
    track_state_change(user, "AWAITING-APPROVAL")
  end

  def track_state_change(user, state)
    uw = UserWork.new(user_id: user.id, work_id: id, state: state)
    uw.save!
  end

  def state_history
    UserWork.where(work_id: id)
  end

  def created_by_user
    User.find(created_by_user_id)
  rescue ActiveRecord::RecordNotFound
    nil
  end
end
