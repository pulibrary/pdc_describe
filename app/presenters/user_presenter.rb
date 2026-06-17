# frozen_string_literal: true
class UserPresenter
  delegate :id, :uid, to: user
  def initialize(user); end
end
