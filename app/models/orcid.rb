# frozen_string_literal: true
require "ezid-client"

class Orcid
  ORCID_REGEX = /^\d\d\d\d-\d\d\d\d-\d\d\d\d-\d\d\d\d$/.freeze

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
