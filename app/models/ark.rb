# frozen_string_literal: true
require "ezid-client"

class Ark
  # Mints a new EZID identifier, returns the id (e.g. "ark:/99999/fk4tq65d6k")
  def self.mint(profile: "dc")
    identifier = Ezid::Identifier.mint
    return identifier.id
  end

  # Updates the target and metadata for a given EZID.
  #
  # id represents the ARK ID returned by `mint` (e.g. "ark:/99999/fk4tq65d6k")
  # target = the new URL that the ID should point to
  # metadata = a hash with the properties to update and its contents depend on
  #   the profile used describe the object (see https://ezid.cdlib.org/doc/apidoc.html#metadata-profiles)
  #
  #   For an item described with Dublin Core metadata would look more or less as follows:
  #
  #   metadata = {
  #     profile: 'dc',
  #     dc_creator: 'hector',
  #     dc_title: 'test title',
  #     dc_publisher: 'super secret',
  #     dc_date: '2022-04-08',
  #   }
  def self.update(id, target, metadata)
    # TODO: implement
  end

  # Returns the information for the indicated ARK ID.
  def self.find(id)
    return Ezid::Identifier.find(id)
  end
end


