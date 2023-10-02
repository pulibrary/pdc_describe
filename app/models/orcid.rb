# frozen_string_literal: true
require "ezid-client"

class Orcid
  # Notice that we allow for an "X" as the last digit.
  # Source https://gist.github.com/asencis/644f174855899b873131c2cabcebeb87
  ORCID_REGEX = /^(\d{4}-){3}\d{3}(\d|X)$/

  def self.valid?(orcid)
    return false if orcid.blank?
    ORCID_REGEX.match(orcid).to_s == orcid
  end

  def self.invalid?(orcid)
    !valid?(orcid)
  end

  def self.url(orcid)
    "https://orcid.org/#{orcid}"
  end
end
