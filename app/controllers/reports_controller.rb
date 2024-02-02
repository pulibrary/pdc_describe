# frozen_string_literal: true
class ReportsController < ApplicationController
  def dataset_list
    @works = Work.all
    if params["format"] == "csv"
      send_data generate_csv(@works), type: "text/plain", filename: "datasets.csv", disposition: "attachment"
    end
  end

  private

    def generate_csv(works)
      text = "TITLE, GROUP, YEAR, TOTAL_FILE_SIZE\r\n"
      works.each do |work|
        text += "#{work.title}, #{work.group.code}, #{work['metadata']['publication_year']}, #{work.total_file_size}\r\n"
      end
      text
    end
end
