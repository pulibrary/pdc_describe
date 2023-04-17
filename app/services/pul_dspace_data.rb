# frozen_string_literal: true
class PULDspaceData
  attr_reader :work, :ark

  def initialize(work)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
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
      if work.s3_query_service.upload_file(io: io, filename: File.basename(filename))
        nil
      else
        "An error uploading #{file_name}.  Please try again."
      end
    end
  end

  private

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
