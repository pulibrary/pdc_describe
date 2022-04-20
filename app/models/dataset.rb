# frozen_string_literal: true

class Dataset < ApplicationRecord
  belongs_to :work

  delegate :title, to: :work
  delegate :created_by_user, to: :work
  delegate :state, to: :work

  before_update do |ds|
    if ds.ark.blank?
      ds.ark = Ark.mint
    end
  end

  def self.my_datasets(user)
    datasets = []
    Work.where(created_by_user_id: user).find_each do |work|
      datasets << Dataset.find(work.dataset_id)
    end
    datasets
  end

  def self.admin_awaiting_datasets(user)
    admin_datasets_by_user_state(user, "AWAITING-APPROVAL")
  end

  def self.admin_withdrawn_datasets(user)
    admin_datasets_by_user_state(user, "WITHDRAWN")
  end

  # Returns that datasets that an admin user has in a given state.
  #
  # Notice that it *excludes* the datasets created by the admin user
  # (since their own datasets will already be shown on their dashboard)
  def self.admin_datasets_by_user_state(user, state)
    admin_collections = []
    Collection.all.find_each do |collection|
      admin_collections << collection if user.can_admin?(collection.id)
    end

    dataset_ids = []
    admin_collections.each do |collection|
      condition = "collection_id = :collection_id AND state = :state AND (created_by_user_id != :user_id)"
      values = { collection_id: collection.id, state: state, user_id: user.id }
      ids = Work.where([condition, values]).map(&:dataset_id)
      dataset_ids += ids
    end

    Dataset.find(dataset_ids)
  end

  def collection_id
    work.collection.id
  end

  def collection_title
    work.collection.title
  end

  def self.create_skeleton(title, user_id, collection_id)
    # Create the work for the dataset...
    work = Work.create_skeleton(title, user_id, collection_id, "DATASET")

    # ...and then the dataset
    ds = Dataset.new(work_id: work.id, profile: "DublinCore")
    ds.save!
    ds
  end

  def ark_url
    "https://ezid.cdlib.org/id/#{ark}"
  end
end
