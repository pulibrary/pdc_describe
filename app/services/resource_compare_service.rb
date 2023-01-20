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
      @before.as_json.keys.map(&:to_sym).each do |method_sym|
        before_value = @before.send(method_sym)
        if before_value.kind_of?(Array)
          after_value = @after.send(method_sym)
          next if before_value.empty? && after_value.empty?
          inside_value = (before_value + after_value).first
          if inside_value.respond_to?(:compare_value)
            compare_object_arrays(method_sym)
          else
            compare_value_arrays(method_sym)
          end
        else
          if before_value.respond_to?(:compare_value)
            compare_objects(method_sym)
          else
            compare_values(method_sym)
          end
        end
      end
    end

    def compare_values(method_sym)
      compare(method_sym) { |value| value }
    end

    def compare_objects(method_sym)
      compare(method_sym) { |value| value.compare_value }
    end

    def compare_value_arrays(method_sym)
      compare(method_sym) { |values| values.join("\n") }
    end

    def compare_object_arrays(method_sym)
      compare(method_sym) { |values| values.map(&:compare_value).join("\n") }
    end

    def compare(method_sym)
      before_value = yield(@before.send(method_sym))
      after_value = yield(@after.send(method_sym))
      if before_value != after_value
        @differences[method_sym] = [{ action: :changed, from: before_value, to: after_value }]
      end
    end
end
