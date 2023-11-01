# frozen_string_literal: true
class RedirectAuditService
  # Select all Work objects that are approved and were migrated
  def migrated_objects
    Work.where(state: "approved").select { |a| a.resource.migrated == true }
  end
end
