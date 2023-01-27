# frozen_string_literal: true

class Domain
  def self.all
    # Values taken from PDC Discovery
    # https://github.com/pulibrary/pdc_discovery/blob/main/lib/traject/domain.rb
    domains = []
    domains << "Engineering"
    domains << "Humanities"
    domains << "Natural Sciences"
    domains << "Social Sciences"
    domains
  end
end
