# frozen_string_literal: true
class Researcher < ApplicationRecord
  def self.new_researcher(first_name, last_name, orcid)
    researcher = Researcher.where(orcid: orcid).first
    if researcher == nil
      researcher = Researcher.new
      researcher.orcid = orcid
    end
    researcher.first_name = first_name
    researcher.last_name = last_name
    researcher.save!
    return researcher
  end

  def self.autocomplete_list(search_term)
    researchers = []
    Researcher.all.each do |researcher|
      if researcher.match?(search_term)
        display_value = "#{researcher.first_name} #{researcher.last_name} (#{researcher.orcid})"
        data = "#{researcher.first_name}|#{researcher.last_name}|#{researcher.orcid}"
        researchers << {value: display_value, data: data}
      end
    end
    return researchers
  end

  def match?(search_term)
    return false if search_term.blank?

    search_term.downcase!
    if (first_name || "").downcase.include?(search_term) || (last_name || "").downcase.include?(search_term)
      return true
    end
    false
  end
end
