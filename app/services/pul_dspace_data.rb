# frozen_string_literal: true
class PULDspaceData
  attr_reader :work, :ark, :keys

  def initialize(work)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
    @keys = []
  end

  def migrate
    return if ark.nil?
    work.resource.migrated = true
    work.save
    migrate_dspace
    aws_copy(aws_files)
  end

  def id
    return nil if ark.nil?
    @id ||= begin
              json = get_data("handle/#{ark}")
              json["id"]
            end
  end

  def bitstreams
    return [] if ark.nil?
    @bitstreams ||= get_data("items/#{id}/bitstreams")
  end

  def metadata
    return {} if ark.nil?
    @metadata ||= begin
                    json = get_data("items/#{id}/metadata")
                    metadata = {}
                    json.each do |value|
                      key = value["key"]
                      metadata[key] = [] if metadata[key].blank?
                      metadata[key] << value["value"]
                    end
                    metadata
                  end
  end

  def download_bitstreams
    return [] if ark.nil?
    bitstreams.map do |bitstream|
      filename = download_bitstream(bitstream["retrieveLink"], bitstream["name"])
      if checksum_file(filename, bitstream)
        filename
      end
    end
  end

  def upload_to_s3(filenames)
    filenames.map do |filename|
      io = File.open(filename)
      key = work.s3_query_service.upload_file(io: io, filename: File.basename(filename))
      if key
        @keys << key
        nil
      else
        "An error uploading #{filename}.  Please try again."
      end
    end
  end

  def doi
    return "" if ark.nil?
    @doi ||= begin
               doi_url = metadata["dc.identifier.uri"].select { |value| value.starts_with?("https://doi.org/") }&.first
               doi_url&.gsub("https://doi.org/", "")
             end
  end

  def aws_files
    return [] if ark.nil? || doi.nil?
    @aws_files ||= work.s3_query_service.client_s3_files(reload: true, bucket_name: dspace_bucket_name, prefix: doi.tr(".", "-"))
  end

  def aws_copy(files)
    files.each do |s3_file|
      DspaceFileCopyJob.perform_later(doi, s3_file.key, s3_file.size, work.id)
      keys << s3_file.key
    end
  end

  def dspace_bucket_name
    @dspace_bucket_name ||= Rails.configuration.s3.dspace[:bucket]
  end

  private

    def migrate_dspace
      filenames = download_bitstreams
      if filenames.any?(nil)
        bitstreams = dspace.bitstreams
        error_files = Hash[filenames.zip bitstreams].select { |key, _value| key.nil? }
        error_names = error_files.map { |bitstream| bitstream["name"] }.join(", ")
        raise "Error downloading file(s) #{error_names}"
      end
      results = upload_to_s3(filenames)
      errors = results.reject(&:"blank?")
      if errors.count > 0
        raise "Error uploading file(s):\n #{errors.join("\n")}"
      end
      filenames.each { |filename| File.delete(filename) }
    end

    def get_data(url_path)
      url = "#{Rails.configuration.dspace.base_url}#{url_path}"
      uri = URI(url)
      http = request_http(url)
      req = Net::HTTP::Get.new uri.path
      response = http.request req
      if response.code != "200"
        Honeybadger.notify("Error retreiving dspace data from #{url} #{response.code} #{response.body}")
        return nil
      end
      JSON.parse(response.body)
    end

    def download_bitstream(retrieval_path, name)
      url = "#{Rails.configuration.dspace.base_url}#{retrieval_path}"
      path = File.join(Rails.configuration.dspace.download_file_path, "dspace_download", work.id.to_s)
      filename = File.join(path, name)
      FileUtils.mkdir_p path
      download_file(url, filename)
      filename
    end

    def download_file(url, filename)
      http = request_http(url)
      uri = URI(url)
      req = Net::HTTP::Get.new uri.path
      http.request req do |response|
        io = File.open(filename, "w")
        response.read_body do |chunk|
          io.write chunk.force_encoding("UTF-8")
        end
        io.close
      end
    end

    def checksum_file(filename, bitstream)
      checksum_class = Digest.const_get(bitstream["checkSum"]["checkSumAlgorithm"])
      if checksum_class.file(filename).hexdigest != bitstream["checkSum"]["value"]
        Rails.logger.error "mismatching checksum #{filename} #{bitstream}"
        Honeybadger.notify("Mismatching checksum #{filename} #{bitstream}")
        false
      else
        Rails.logger.debug "Matching checksums for #{filename}"
        true
      end
    rescue NameError
      Honeybadger.notify("Unknown checksum algorithm #{bitstream['checkSum']['checkSumAlgorithm']} #{filename} #{bitstream}")
      false
    end

    def request_http(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end
end
