# frozen_string_literal: true
require "csv"

namespace :orcid do
  desc "Populate ORCID IDs in user accounts based on a spreadsheet"
  task populate: :environment do
    source = ENV["SOURCE_CSV"]

    CSV.foreach(source, :headers => true) do |entry|

      next if entry["Net ID"] == "N/A"

      email = "#{entry["Net ID"]}@princeton.edu"
      uid = entry["Net ID"]
      full_name = "#{entry["First Name"]} #{entry["Last Name"]}"
      display_name = entry["First Name"]
      orcid = entry["ORCID ID"]

      u = User.where(:email => email).first_or_create

      params_hash = {
        :email => email,
        :uid => uid,
        :orcid => orcid,
        full_name: (full_name unless u.full_name.present?),
        display_name: (display_name unless u.display_name.present?)
      }.compact

      u.update(params_hash)
    end


  end
end
