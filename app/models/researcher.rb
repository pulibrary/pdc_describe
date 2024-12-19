# frozen_string_literal: true
class Researcher < ApplicationRecord
  def self.new_researcher(first_name, last_name, orcid, netid)
    researcher = Researcher.where(orcid: orcid).first
    if researcher == nil
      researcher = Researcher.new
      researcher.netid = netid
    end
    researcher.first_name = first_name
    researcher.last_name = last_name
    researcher.orcid = orcid
    researcher.save!
    return researcher
  end

  def self.autocomplete_list
    researchers = []
    Researcher.all.each do |researcher|
      display_value = "#{researcher.first_name} #{researcher.last_name} (#{researcher.netid})"
      researchers << {value: display_value, data: researcher.netid}
    end
    return researchers
  end
end
