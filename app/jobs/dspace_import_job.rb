
class DSpaceImportJob < ApplicationJob
  def perform(url:, user:, collection:, work_type: nil)
    service = DSpaceImportService.new(url: url, user: user, collection: collection, work_type: work_type)
    service.import!
  end
end
