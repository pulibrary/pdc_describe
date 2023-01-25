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
      # Loop through an object's setters and compare the values from the before and after objects.
      # Note: This assumes the before and after objects have the same methods.
      setters = @before.methods.map(&:to_s).filter { |s| s.match?(/\w=$/) }
      setters.map { |s| s.gsub("=","").to_sym }.each do |method_sym|
        before_value = @before.send(method_sym)
        after_value = @after.send(method_sym)
        next if before_value.to_json == after_value.to_json
        if before_value.is_a?(Array)
          compare_arrays(method_sym, before_value, after_value)
        elsif before_value.respond_to?(:compare_value) || after_value.respond_to?(:compare_value)
          # If either value is nil, we still want to get the compare_value for the other.
          compare_objects(method_sym)
        else
          compare_values(method_sym)
        end
      end
    end

    def compare_arrays(method_sym, before_array, after_array)
      inside_value = (before_array + after_array).first
      if inside_value.respond_to?(:compare_value)
        compare_object_arrays(method_sym)
      else
        compare_value_arrays(method_sym)
      end
    end

    def compare_values(method_sym)
      compare(method_sym, &:to_s)
    end

    def compare_objects(method_sym)
      compare(method_sym) { |value| value.nil? ? "" : value.compare_value }
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
