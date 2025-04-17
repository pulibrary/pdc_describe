# frozen_string_literal: true
namespace :embargo do
  desc "releases all files from works that left embargo yesterday"
  task release: :environment do
    Work.list_released_embargo.each do |work|
      WorkEmbargoReleaseService.new(work:).move
    end
  end
end
