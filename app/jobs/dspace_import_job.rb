# frozen_string_literal: true

class DSpaceImportJob < ApplicationJob
  def perform(url:, user_id:, collection_id:, work_type: nil)
    user = User.find(user_id)
    collection = User.find(collection_id)

    service = DSpaceImportService.new(url: url, user: user, collection: collection, work_type: work_type)
    service.import!
  end
end
