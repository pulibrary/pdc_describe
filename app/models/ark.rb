# frozen_string_literal: true
require "ezid-client"

class Ark
  # Mints a new EZID identifier, returns the id (e.g. "ark:/99999/fk4tq65d6k")
  def self.mint
    identifier = Ezid::Identifier.mint
    identifier.id
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
