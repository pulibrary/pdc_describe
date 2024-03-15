# frozen_string_literal: true

class WorkCompareService
  attr_reader :differences

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
