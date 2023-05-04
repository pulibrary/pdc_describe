# frozen_string_literal: true
class WorkPresenter
  attr_reader :work

  delegate :resource, to: :work

  def initialize(work:)
    @work = work
  end

  def description
    value = resource.description
    Rinku.auto_link(value, :all, 'target="_blank"')
  end
end
