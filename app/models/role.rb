# frozen_string_literal: true
#  Code was autogenerated by running `rails g rolify Role User`
class Role < ApplicationRecord
  # rubocop:disable Rails/HasAndBelongsToMany
  #  Had to put the generated code back.  The rubocop reccomended code did not allow for deletes
  has_and_belongs_to_many :users, join_table: :users_roles
  # rubocop:enable Rails/HasAndBelongsToMany

  belongs_to :resource,
             polymorphic: true,
             optional: true

  validates :resource_type,
            inclusion: { in: Rolify.resource_types },
            allow_nil: true

  scopify
end
