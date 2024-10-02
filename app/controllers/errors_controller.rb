# frozen_string_literal: true
class ErrorsController < ApplicationController
  skip_before_action :authenticate_user!

  def not_found
    render(status: :not_found)
  end

  def internal_server_error
    render(status: :internal_server_error)
  end
end
