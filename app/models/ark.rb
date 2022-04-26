# frozen_string_literal: true
require "ezid-client"

class Ark
  # Mints a new EZID identifier, returns the id (e.g. "ark:/99999/fk4tq65d6k")
  def self.mint
    return "ark:/99999/fk4tq65d6k" if Rails.env.test?
    identifier = Ezid::Identifier.mint
    identifier.id
  end

  def self.find(ezid)
    Ezid::Identifier.find(ezid)
  rescue Net::HTTPServerException
    nil
  rescue StandardError => error
    Rails.logger.error("Failed to find the EZID #{ezid}: #{error.message}")
    nil
  end

  # Determines whether or not a given EZID string is a valid ARK
  # @param [ezid] [String] the EZID being validated
  # @return [Boolean]
  def self.valid?(ezid)
    resolved = find(ezid)
    !resolved.nil?
  end

  def initialize(ezid)
    @object = self.class.find(ezid)
    raise(ArgumentError, "Invalid EZID provided for an ARK: #{ezid}") if @object.nil?
  end

  def object
    @object ||= self.class.find(ezid)
  end

  delegate :id, :metadata, to: :object

  def target
    metadata[Ezid::Metadata::TARGET]
  end

  def target=(value)
    metadata[Ezid::Metadata::TARGET] = value
  end

  def save!
    object.modify(id, metadata)
  end

  # ======================
  # If in the future we want to update the information of the ARK we can
  # implement a few methods as follow:
  #
  # Update the target URL of the ARK to point to a new URL
  # def self.update_target(id, new_url)
  #   identifier = Ezid::Identifier.find(id)
  #   identifier.target = new_url
  #   identifier.save
  # end
  #
  # Update the metadata for an ARK. See https://ezid.cdlib.org/doc/apidoc.html#metadata-profiles
  # for details on the profiles supported.
  #
  # def self.update_metadata(id)
  #   metadata = {
  #     profile: 'dc',
  #     dc_creator: 'somebody',
  #     dc_title: 'some title',
  #     dc_date: '2022-04-08',
  #   }
  #   identifier = Ezid::Identifier.modify(id, metadata)
  # end
  # ======================
end
