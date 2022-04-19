# frozen_string_literal: true
class WorksController < ApplicationController
  def index
    @works = Works.all
  end
end
