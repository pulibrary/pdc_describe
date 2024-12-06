# frozen_string_literal: true
class Creator < ApplicationRecord
  def self.new_creator(first_name, last_name, orcid, netid)
    user = Creator.where(netid: netid).first
    if user == nil
      user = Creator.new
      user.netid = netid
    end
    user.first_name = first_name
    user.last_name = last_name
    user.orcid = orcid
    user.save!
    return user
  end
end
