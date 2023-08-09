# frozen_string_literal: true
class PULDspaceConnector
  attr_reader :work, :ark, :download_base

  def initialize(work)
    @work = work
    @ark = work.ark&.gsub("ark:/", "")
    @download_base = "#{Rails.configuration.dspace.base_url.gsub('rest/', '')}bitstream/#{ark}"
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

  def list_bitsteams
    @list_bitsteams ||=
      bitstreams.map do |bitstream|
        path = File.join(Rails.configuration.dspace.download_file_path, "dspace_download", work.id.to_s)
        filename = File.join(path, bitstream["name"])
        if bitstream["checkSum"]["checkSumAlgorithm"] != "MD5"
          Honeybadger.notify("Unknown checksum algorithm #{bitstream['checkSum']['checkSumAlgorithm']} #{filename} #{bitstream}")
        end

        S3File.new(filename_display: bitstream["name"], checksum: base64digest(bitstream["checkSum"]["value"]), last_modified: DateTime.now,
                   size: -1, work: work, url: "#{download_base}/#{bitstream['sequenceId']}", filename: filename)
      end
  end

  def download_bitstreams(bitstream_list)
    bitstream_list.map do |file|
      filename = download_bitstream(file.url, file.filename)
      if checksum_file(filename, file.checksum)
        file
      else
        { file: file, error: "Checsum Missmatch" }
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

    def download_bitstream(retrieval_url, filename)
      path = File.join(Rails.configuration.dspace.download_file_path, "dspace_download", work.id.to_s)
      FileUtils.mkdir_p path
      download_file(retrieval_url, filename)
      filename
    end

    def download_file(url, filename)
      stdout_and_stderr_str, status = Open3.capture2e("wget -c '#{url}' -O '#{filename}'")
      unless status.success?
        Honeybadger.notify("Error dowloading file #{url} for work id #{work.id} to #{filename}! Error: #{stdout_and_stderr_str}")
      end
    end

    def checksum_file(filename, original_checksum)
      checksum = Digest::MD5.file(filename)
      base64 = checksum.base64digest
      if base64 != original_checksum
        msg = "Mismatching checksum #{filename} #{original_checksum} for work: #{work.id} doi: #{work.doi} ark: #{work.ark}"
        Rails.logger.error msg
        Honeybadger.notify(msg)
        false
      else
        Rails.logger.debug "Matching checksums for #{filename}"
        true
      end
    end

    def base64digest(hexdigest)
      [[hexdigest].pack("H*")].pack("m0")
    end

    def request_http(url)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http
    end
end
