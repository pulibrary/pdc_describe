# frozen_string_literal: true

class DspaceImportJob < ApplicationJob
  def perform(url:, user_id:, collection_id:, work_type: nil)
    user = User.find_by(id: user_id)
    collection = User.find_by(id: collection_id)

    service = DspaceImportService.new(url: url, user: user, collection: collection, work_type: work_type)
    service.import!
  end
end
