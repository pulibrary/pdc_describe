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
      service = S3QueryService.new(work, "postcuration")
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
      service = S3QueryService.new(work, "postcuration")
      work.pre_curation_uploads.each { |upload| service.client.delete_object({ bucket: service.bucket_name, key: upload.key }) }
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
      work = Work.new(resource:)
      work.group = Group.where(code: hash["group"]["code"]).first
      work.created_by_user_id = approver.id
      work.draft!(approver)
      puts "\t#{file_name}"
    end
  end

  # Use this to figure out what works don't have the proper DataCite attributes
  # (useful when troubleshooting bad data already in the system)
  desc "Shows what works are valid for DataCite submission."
  task :validate_datacite_attributes, [:verbose] => :environment do |_, args|
    Work.all.each do |work|
      _attributes = work.resource.to_xml
    rescue => ex
      details = args[:verbose] == "true" ? ex.backtrace.join : ""
      puts "Work #{work.id} is not valid, #{ex.message}. #{details}"
    end
  end

  desc "Creates the preservation objects for a given work and saves them in the preservation bucket configured"
  task :preserve, [:work_id, :path] => :environment do |_, args|
    work_id = args[:work_id].to_i
    path = args[:path] # e.g. "10.34770/xy123/10"
    work_preservation = WorkPreservationService.new(work_id:, path:)
    puts work_preservation.preserve!
  end

  desc "Creates the preservation objects for a given work and saves them locally on disk"
  task :preserve_local, [:work_id, :path] => :environment do |_, args|
    work_id = args[:work_id].to_i
    path = args[:path] # e.g. "10.34770/xy123/10"
    work_preservation = WorkPreservationService.new(work_id:, path:, localhost: true)
    puts work_preservation.preserve!
  end

  # Artificially add a lot of notifications to a work
  # (Will be used to test https://github.com/pulibrary/pdc_describe/issues/1978 in staging )
  task :big_provenance, [:work_id] => :environment do |_, args|
    work_id = args[:work_id].to_i
    user = User.find_by(uid: "hc8719")
    datestamp = DateTime.now.to_s
    (0..2000).each do |_i|
      WorkActivity.add_work_activity(work_id, "SYSTEM #{datestamp} - #{rand(1_000_000)}", user.id, activity_type: WorkActivity::SYSTEM)
    end
    (0..40).each do |_i|
      WorkActivity.add_work_activity(work_id, "MESSAGE #{datestamp} - #{rand(1_000_000)} @hc8719", user.id, activity_type: WorkActivity::MESSAGE)
    end
    work = Work.find(work_id)
    puts work.activities.count
  end

  desc "Clean up the duplicate globus and data_space files in a work from migration"
  task :migration_cleanup, [:work_id, :force] => :environment do |_, args|
    work_id = args[:work_id].to_i
    force = ActiveModel::Type::Boolean.new.cast(args[:force])
    work = Work.find(work_id)
    files = work.s3_files
    globus_files = files.select { |file| file.filename.include?("/globus_") }
    data_space_files = files.select { |file| file.filename.include?("/data_space_") }
    if globus_files.count != data_space_files.count
      puts "Error processing files.  The counts differ! globus: #{globus_files.count} data_space: #{data_space_files.count}"
      exit 1
    end

    all_match = (0..(globus_files.count - 1)).all? { |idx| globus_files[idx].checksum == data_space_files[idx].checksum }
    if all_match || force
      puts "deleting matching #{data_space_files.count} dpsace files"
      bucket = PULS3Client.pre_curation_config[:bucket]
      data_space_files.each do |file|
        work.s3_query_service.delete_s3_object(file.key, bucket:)
      end
      puts "copying #{globus_files.count} globus files to original name"
      globus_files.each do |file|
        new_key = file.key.gsub("globus_", "")
        work.s3_query_service.copy_file(source_key: "#{bucket}/#{file.key}", target_bucket: bucket, target_key: new_key, size: file.size)
      end
      puts "deleting #{globus_files.count} globus prefixed files"
      globus_files.each do |file|
        work.s3_query_service.delete_s3_object(file.key, bucket:)
      end
    else
      puts "checksums do not match for this work"
      (0..(globus_files.count - 1)).each do |idx|
        if globus_files[idx].checksum != data_space_files[idx].checksum
          puts "#{globus_files[idx].filename} #{globus_files[idx].checksum} #{data_space_files[idx].filename} #{data_space_files[idx].checksum}"
        end
      end
    end
  end

  desc "Clean up the duplicates keeping data_space files in a work from migration"
  task :migration_cleanup_keep_dataspace, [:work_id, :force] => :environment do |_, args|
    work_id = args[:work_id].to_i
    force = ActiveModel::Type::Boolean.new.cast(args[:force])
    work = Work.find(work_id)
    files = work.s3_files
    globus_files = files.select { |file| file.filename.include?("/globus_") }
    data_space_files = files.select { |file| file.filename.include?("/data_space_") }
    if (globus_files.count != data_space_files.count) && !force
      puts "Error processing files.  The counts differ! globus: #{globus_files.count} data_space: #{data_space_files.count}"
      exit 1
    end

    all_match = (0..(globus_files.count - 1)).all? { |idx| globus_files[idx].checksum == data_space_files[idx].checksum }
    if all_match || force
      puts "deleting matching #{globus_files.count} globus files"
      bucket = PULS3Client.pre_curation_config[:bucket]
      globus_files.each do |file|
        work.s3_query_service.delete_s3_object(file.key, bucket:)
      end
      puts "copying #{data_space_files.count} data space files to original name"
      data_space_files.each do |file|
        new_key = file.key.gsub("data_space_", "")
        work.s3_query_service.copy_file(source_key: "#{bucket}/#{file.key}", target_bucket: bucket, target_key: new_key, size: file.size)
      end
      puts "deleting #{data_space_files.count} data_space prefixed files"
      data_space_files.each do |file|
        work.s3_query_service.delete_s3_object(file.key, bucket:)
      end
    else
      puts "checksums do not match for this work"
      (0..(globus_files.count - 1)).each do |idx|
        if globus_files[idx].checksum != data_space_files[idx].checksum
          puts "#{globus_files[idx].filename} #{globus_files[idx].checksum} #{data_space_files[idx].filename} #{data_space_files[idx].checksum}"
        end
      end
    end
  end

  desc "Rename files in a work from migration that should have been renamed, but were not"
  task :migration_rename_aws, [:work_id] => :environment do |_, args|
    work_id = args[:work_id].to_i

    work = Work.find(work_id)
    bucket = work.bucket_name
    service = S3QueryService.new(work, "precuration")
    uri = service.file_url("#{service.prefix}renamed_files.txt")
    filename = "/tmp/#{work.id}renamed_files.txt"
    stdout_and_stderr_str, status = Open3.capture2e("wget -c '#{uri}' -O '#{filename}'")

    if status.success?
      s3_files = work.s3_files
      File.readlines(filename, chomp: true).each do |line|
        next unless line.starts_with?(work.doi)
        original_name, new_name = line.split("\t")
        file_index = s3_files.index { |file| file.key == original_name }
        if file_index
          puts "will rename #{original_name} to #{new_name}"
          work.s3_query_service.copy_file(source_key: "#{bucket}/#{ERB::Util.url_encode(original_name)}", target_bucket: bucket, target_key: new_name, size: s3_files[file_index].size)
          work.s3_query_service.delete_s3_object(original_name, bucket:)
        else
          puts "New name already present #{new_name}"
        end
      end
    else
      puts "Error dowloading file #{uri} for work id #{work.id} to #{filename}! Error: #{stdout_and_stderr_str}"
    end
  end
end
