# frozen_string_literal: true
class ReportsController < ApplicationController
  def dataset_list
    @works = Work.where(sql_where(params))
    if params["format"] == "csv"
      send_data generate_csv(@works), type: "text/plain", filename: "datasets.csv", disposition: "attachment"
    end
  end

  private

    def generate_csv(works)
      text = "TITLE, STATUS, GROUP, YEAR, TOTAL_FILE_SIZE\r\n"
      works.each do |work|
        text += "#{work.title}, #{work.state}, #{work.group.code}, #{work['metadata']['publication_year']}, #{work.total_file_size}\r\n"
      end
      text
    end

    def sql_where(params)
      sql_where = []
      if params["status"] == "finished"
        sql_where << "state = 'approved'"
      elsif params["status"] == "unfinished"
        sql_where << "state != 'approved'"
      end

      if params["group"].present? && params["group"] != "ALL"
        group_id = Group.where(code: params['group']).first.id
        sql_where << "group_id = #{group_id}"
      end

      if params["year"].present? && params["year"] != "ALL"
        year = params['year'].to_i # Force to int to guard against SQL injection
        sql_where << "metadata->>'publication_year' = '#{year}'"
      end
      sql_where.join(" AND ")
    end
end
