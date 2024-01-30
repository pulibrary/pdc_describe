# frozen_string_literal: true
class ReportsController < ApplicationController
    def index
        @works = Work.all
        #@works[0]["metadata"]["publication_year"]
        #@works[0].title
        #@works[0].group.title
        #@works[0].total_file_size
    end
    
end
  