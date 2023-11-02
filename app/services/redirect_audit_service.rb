# frozen_string_literal: true
class RedirectAuditService
  # Select all Work objects that are approved and were migrated,
  # since these are the works that should have been redirected.
  def redirected_works
    Work.where(state: "approved").select { |a| a.resource.migrated == true }
  end

  def ark_redirected?(ark)
    return true if ark.target.match?(/datacommons\.princeton\.edu/)
    false
  end
end
