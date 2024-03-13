# frozen_string_literal: true
class ReportsController < ApplicationController
  def dataset_list
    if current_user.super_admin? || current_user.moderator?
      @works = Work.where(sql_where(params))
    else
      redirect_to "/"
    end
  end

  private

    def sql_where(params)
      sql_where = []
      if params["status"] == "finished"
        sql_where << "state = 'approved'"
      elsif params["status"] == "unfinished"
        sql_where << "state != 'approved'"
      end

      if params["group"].present? && params["group"] != "ALL"
        group_id = Group.where(code: params["group"]).first.id
        sql_where << "group_id = #{group_id}"
      end

      if params["year"].present? && params["year"] != "ALL"
        year = params["year"].to_i # Force to int to guard against SQL injection
        sql_where << "metadata->>'publication_year' = '#{year}'"
      end
      sql_where.join(" AND ")
    end
end
