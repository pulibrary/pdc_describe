# frozen_string_literal: true

# Compares two PDCMetadata::Resource objects and provides a hash with the `differences`
#
# If there are no differences between the two objects `identical?` returns `true` and `differences == {}`
# If there are differences the `differences` hash has the following structure:
#
# ```
#    :field_name = [{action:, from: to:, value: }]
# ```
#
# The array for ``:field_name` lists all the changes that happened to the field.
# For single-value fields is always a single element array, for multi-value fields
# in can contain multiple elements.
#
# The `action` indicates whether a value changed, was added, or deleted.
#
# rubocop:disable Metrics/ClassLength
class ResourceCompareService
  attr_reader :differences

  def initialize(before, after)
    @before = before
    @after = after
    @differences = {}
    compare_resources
  end

  def identical?
    @differences == {}
  end

  private

    def compare_resources
      [:titles, :creators, :contributors].each do |field|
        compare_objects(field)
      end
      compare_simple_values
      compare_rights
      compare_keywords
      compare_collection_tags
    end

    ##
    # Compares simple single values between the two resources.
    def compare_simple_values
      field_names = [:description, :publisher, :publication_year, :resource_type, :resource_type_general,
                     :doi, :ark, :version_number]

      field_names.each do |field_name|
        before_value = @before.send(field_name)
        after_value = @after.send(field_name)
        if before_value != after_value
          @differences[field_name] = [{ action: :changed, from: before_value, to: after_value }]
        end
      end
    end

    def compare_rights
      before_value = @before.rights&.name
      after_value = @after.rights&.name
      if before_value != after_value
        @differences[:rights] = [{ action: :changed, from: before_value, to: after_value }]
      end
    end

    def compare_keywords
      changes = compare_arrays(@before.keywords, @after.keywords)
      @differences[:keywords] = changes if changes.count > 0
    end

    def compare_collection_tags
      changes = compare_arrays(@before.collection_tags, @after.collection_tags)
      @differences[:collection_tags] = changes if changes.count > 0
    end

    ##
    # Compares two arrays of simple string values.
    # Returns an array with the changes (values removed, values added)
    def compare_arrays(before_values, after_values)
      changes = []
      removed = before_values - after_values
      added = after_values - before_values
      common = (before_values + after_values).uniq - removed - added

      before_values.each do |value|
        changes << { action: :removed, value: value } unless value.in?(common)
      end

      after_values.each do |value|
        changes << { action: :added, value: value } if value.in?(added)
      end

      changes
    end

    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def compare_objects(method_sym)
      changes = []
      keys_before = @before.send(method_sym).map(&:compare_value)
      keys_after = @after.send(method_sym).map(&:compare_value)

      removed = keys_before - keys_after
      added = keys_after - keys_before
      common = (keys_before + keys_after).uniq - removed - added

      @before.send(method_sym).each do |before_object|
        if before_object.compare_value.in?(common)
          after_object = @after.send(method_sym).find { |c| c.compare_value == before_object.compare_value }
          if before_object.compare_value != after_object.compare_value
            changes << { action: :changed, from: before_object.compare_value, to: after_object.compare_value }
          end
        elsif before_object.compare_value.in?(removed)
          changes << { action: :removed, value: before_object.compare_value }
        end
      end

      @after.send(method_sym).each do |after_object|
        if after_object.compare_value.in?(added)
          changes << { action: :added, value: after_object.compare_value }
        end
      end

      @differences[method_sym] = changes if changes.count > 0
    end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ClassLength
