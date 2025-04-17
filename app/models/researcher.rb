# frozen_string_literal: true
class Researcher < ApplicationRecord
  def self.new_researcher(first_name, last_name, orcid)
    researcher = Researcher.where(orcid:).first
    if researcher.nil?
      researcher = Researcher.new
      researcher.orcid = orcid
    end
    researcher.first_name = first_name
    researcher.last_name = last_name
    researcher.save!
    researcher
  end

  def self.autocomplete_list(search_term)
    researchers = []
    researchers_list = (Researcher.where("first_name ILIKE ? OR last_name ILIKE ?", "%"+search_term+"%", "%"+search_term+"%"))
    researchers_list.each do |researcher|
      display_value = "#{researcher.first_name} #{researcher.last_name} (#{researcher.orcid})"
      data = "#{researcher.first_name}|#{researcher.last_name}|#{researcher.orcid}"
      researchers << { value: display_value, data: data}
    end
    researchers
  end
end
