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
      [:titles, :creators, :contributors, :related_objects].each do |field|
        compare_objects(field)
      end
      [:description, :publisher, :publication_year,
       :resource_type, :resource_type_general,
       :doi, :ark, :version_number].each do |field|
        compare_simple_values(field)
      end
      compare_rights
      [:keywords, :collection_tags].each do |field|
        compare_arrays(field)
      end
    end

    ##
    # Compares simple single value between the two resources.
    def compare_simple_values(method_sym)
      before_value = @before.send(method_sym)
      after_value = @after.send(method_sym)
      if before_value != after_value
        @differences[method_sym] = [{ action: :changed, from: before_value, to: after_value }]
      end
    end

    def compare_rights
      before_value = @before.rights&.name
      after_value = @after.rights&.name
      if before_value != after_value
        @differences[:rights] = [{ action: :changed, from: before_value, to: after_value }]
      end
    end

    ##
    # Compares two arrays of simple string values.
    # Returns an array with the changes (values removed, values added)
    def compare_arrays(method_sym)
      before_value = @before.send(method_sym).join("\n")
      after_value = @after.send(method_sym).join("\n")
      if before_value != after_value
        @differences[method_sym] = [{ action: :changed, from: before_value, to: after_value }]
      end
    end

    def compare_objects(method_sym)
      before_value = @before.send(method_sym).map(&:compare_value).join("\n")
      after_value = @after.send(method_sym).map(&:compare_value).join("\n")
      if before_value != after_value
        @differences[method_sym] = [{ action: :changed, from: before_value, to: after_value }]
      end
    end
end
