# frozen_string_literal: true
class GroupOption < ApplicationRecord
  EMAIL_MESSAGES = 0

  belongs_to :group, class_name: "Group"
  belongs_to :user

  enum :option_type, { email_messages: 0 }

  # Provides a human-readable label for the type of the option
  # @note This should perhaps in the future parse from a YAML config. file
  # @return [String] the label
  def self.option_type_labels
    {
      email_messages: "E-mail messages for Group notifications"
    }
  end

  # Finds the label for the option type value set for a given Model
  # @param [Integer] value the option type value
  # @return [String] the label
  def self.find_option_type_label(value)
    option_type_labels.fetch(value.to_sym, nil)
  end

  # Finds the label for the option type
  # @return [String] the label
  def option_type_label
    self.class.find_option_type_label(option_type)
  end
end
