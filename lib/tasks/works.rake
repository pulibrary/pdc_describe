# frozen_string_literal: true
namespace :works do
  desc "Transfers DOI value from Work.doi to Work.resource.doi"
  task transfer_doi_fix: :environment do
    Work.all.each do |work|
      if work.resource.doi.nil?
        if work.doi.present?
          work.resource.doi = work.doi
          if work.save
            puts "#{work.id} - Fixed"
          else
            puts "#{work.id} - #{work.errors.errors.map(&:type)}"
          end
        else
          work.doi = "10.80021/tbd"
          puts "#{work.id} - Can't be fixed, try again? #{work.save}"
        end
      else
        puts "#{work.id} - OK"
      end
    end
  end

  desc "Delete works from a user"
  task :delete_user_works, [:user_netid] => :environment do |_, args|
    if args[:user_netid].blank?
      puts "Usage: bundle exec rake works:delete_user_works\\[<netid>\\]"
      exit 1
    end
    userid = args[:user_netid]
    user = User.find_by(uid: userid)
    if user.blank?
      puts "No records exist for that user"
      exit 1
    end
    works = Work.where(created_by_user_id: user.id)
    works.each do |work|
      work.pre_curation_uploads.each(&:destroy)
      service = S3QueryService.new(work, false)
      work.post_curation_uploads.each { |upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key }) }
      work.destroy
    end
  end

  desc "Delete all works except the passed excluded list"
  task :delete_works_not_including, [:excluded_works] => :environment do |_, args|
    if args[:excluded_works].blank?
      puts "Usage: bundle exec rake works:delete_works_not_including\\[<workid>+<workid>\\]"
      exit 1
    end
    works_str = args[:excluded_works]
    work_exclusion_ids = works_str.split("+").map(&:to_i)
    works = Work.where.not(id: work_exclusion_ids)
    works.each do |work|
      work.pre_curation_uploads.each(&:destroy)
      service = S3QueryService.new(work, false)
      work.post_curation_uploads.each { |upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key }) }
      work.destroy
    end
  end

  # See https://github.com/pulibrary/pdc_describe/blob/main/docs/test_data_in_production.md for
  # more information.
  # Example: rake works:import_works\[/Users/bess/projects/pdc_describe/tmp/data_migration,bs3097]
  desc "Imports works from JSON data"
  task :import_works, [:path, :uid] => :environment do |_, args|
    if args[:path].blank?
      puts "Usage: bundle exec rake works:import_works\\[path_to_json_files,uid]"
      exit 1
    end
    path = File.join(args[:path], "*.json")
    approver = User.find_or_create_by uid: args[:uid]
    puts "Importing files from: #{path}"
    Dir.glob(path).each do |file_name|
      hash = JSON.parse(File.read(file_name))
      resource = PDCMetadata::Resource.new_from_jsonb(hash["resource"])
      work = Work.new(resource: resource)
      work.collection = Collection.where(code: hash["collection"]["code"]).first
      work.created_by_user_id = approver.id
      work.state = "draft"
      work.save
      puts "\t#{file_name}"
    end
  end
end
