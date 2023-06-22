# frozen_string_literal: true
class PULDspaceConnector
  attr_reader :work, :ark

  def initialize(work)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
  end

  def id
    @id ||= begin
              json = get_data("handle/#{ark}")
              json["id"]
            end
  end

  def bitstreams
    @bitstreams ||= get_data("items/#{id}/bitstreams")
  end

  def metadata
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
    bitstreams.map do |bitstream|
      filename = download_bitstream(bitstream["retrieveLink"], bitstream["name"])
      if checksum_file(filename, bitstream)
        S3File.new(filename: filename, checksum: bitstream["checkSum"]["base64"], last_modified: DateTime.now, size: -1, work: work)
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

  private

    def get_data(url_path)
      return {} if ark.nil?

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

    # rubocop:disable Metrics/MethodLength
    def checksum_file(filename, bitstream)
      checksum_class = Digest.const_get(bitstream["checkSum"]["checkSumAlgorithm"])
      checksum = checksum_class.file(filename)
      hexdigest = checksum.hexdigest
      base64 = checksum.base64digest
      bitstream["checkSum"]["base64"] = base64
      if hexdigest != bitstream["checkSum"]["value"]
        msg = "Mismatching checksum #{filename} #{bitstream} for work: #{work.id} doi: #{work.doi} ark: #{work.ark}"
        Rails.logger.error msg
        Honeybadger.notify(msg)
        false
      else
        Rails.logger.debug "Matching checksums for #{filename}"
        true
      end
    rescue NameError
      Honeybadger.notify("Unknown checksum algorithm #{bitstream['checkSum']['checkSumAlgorithm']} #{filename} #{bitstream}")
      false
    end
    # rubocop:enable Metrics/MethodLength

    def request_http(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end
end
