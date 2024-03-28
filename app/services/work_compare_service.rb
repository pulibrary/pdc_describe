# frozen_string_literal: true

class WorkCompareService
  attr_reader :differences

  class << self
    # Updates a work with the parameters and logs any changes
    # @param [Work] work work to be updated
    # @param [HashWithIndifferentAccess] update_params values to update the work with
    # @param [] current_user user currently logged into the system
    # @return [Boolean] true if update occured; false if update had errors
    def update_work(work:, update_params:, current_user:)
      work_before = work.dup
      if work.update(update_params)
        work_compare = new(work_before, work)
        work.log_changes(work_compare, current_user.id)
        true
      else
        false
      end
    end
  end

  def initialize(before, after)
    @before = before
    @after = after
    @differences = {}
    compare_works
  end

  def identical?
    @differences == {}
  end

  private

    def resource_compare_service
      @resource_compare_service ||= ResourceCompareService.new(@before.resource, @after.resource)
    end

    def compare_works
      # Compare the group
      if @before.group != @after.group
        before_value = @before.group
        after_value = @after.group
        @differences[:group] = [{ action: :changed, from: before_value.title, to: after_value.title }]
      end

      @differences = @differences.merge(resource_compare_service.differences)
    end
end
