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
      compare_titles
      compare_creators
      compare_contributors
      [:description, :publisher, :publication_year,
        :resource_type, :resource_type_general,
        :doi, :ark, :version_number
      ].each do |field|
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
      before_values = @before.send(method_sym)
      after_values = @after.send(method_sym)
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

      @differences[method_sym] = changes if changes.count > 0
    end

    ##
    # Compares the titles between the two resources. This is a bit tricky because we support many
    # titles and the title itself is an object with two properties (title and title_type)
    # Returns an array with the changes (values removed, values added, values changed)
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def compare_titles
      changes = []
      keys_before = @before.titles.map(&:title_type)
      keys_after = @after.titles.map(&:title_type)

      removed = keys_before - keys_after
      added = keys_after - keys_before
      common = (keys_before + keys_after).uniq - removed - added

      @before.titles.each do |before_title|
        if before_title.title_type.in?(common)
          after_title = @after.titles.find { |t| t.title_type == before_title.title_type }
          if before_title.title != after_title.title
            changes << { action: :changed, from: before_title.title, to: after_title.title }
          end
        elsif before_title.title_type.in?(removed)
          changes << { action: :removed, value: before_title.title }
        end
      end

      @after.titles.each do |after_title|
        if after_title.title_type.in?(added)
          changes << { action: :added, value: after_title.title }
        end
      end

      @differences[:titles] = changes if changes.count > 0
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    ##
    # Compares the creators between the two resources. This is a bit tricky because we support many
    # creators and the creator objects have many properties.
    # Returns an array with the changes (values removed, values added, values changed)
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def compare_creators
      changes = []
      keys_before = @before.creators.map(&:compare_value)
      keys_after = @after.creators.map(&:compare_value)

      removed = keys_before - keys_after
      added = keys_after - keys_before
      common = (keys_before + keys_after).uniq - removed - added

      @before.creators.each do |before_creator|
        if before_creator.compare_value.in?(common)
          after_creator = @after.creators.find { |c| c.compare_value == before_creator.compare_value }
          if before_creator.compare_value != after_creator.compare_value
            changes << { action: :changed, from: before_creator.compare_value, to: after_creator.compare_value }
          end
        elsif before_creator.compare_value.in?(removed)
          changes << { action: :removed, value: before_creator.compare_value }
        end
      end

      @after.creators.each do |after_creator|
        if after_creator.compare_value.in?(added)
          changes << { action: :added, value: after_creator.compare_value }
        end
      end

      @differences[:creators] = changes if changes.count > 0
    end
    # rubocop:enable Metrics/PerceivedComplexity
    # rubocop:enable Metrics/CyclomaticComplexity
    # rubocop:enable Metrics/AbcSize
    # rubocop:enable Metrics/MethodLength

    ##
    # Compares the contributors between the two resources. This is a bit tricky because we support many
    # contributors and the contributor objects have many properties.
    # Returns an array with the changes (values removed, values added, values changed)
    # rubocop:disable Metrics/MethodLength
    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/CyclomaticComplexity
    # rubocop:disable Metrics/PerceivedComplexity
    def compare_contributors
      changes = []
      keys_before = @before.contributors.map(&:compare_value)
      keys_after = @after.contributors.map(&:compare_value)

      removed = keys_before - keys_after
      added = keys_after - keys_before
      common = (keys_before + keys_after).uniq - removed - added

      @before.contributors.each do |before_contributor|
        if before_contributor.compare_value.in?(common)
          after_contributor = @after.contributors.find { |c| c.compare_value == before_contributor.compare_value }
          if before_contributor.compare_value != after_contributor.compare_value
            changes << { action: :changed, from: before_contributor.compare_value, to: after_contributor.compare_value }
          end
        elsif before_contributor.compare_value.in?(removed)
          changes << { action: :removed, value: before_contributor.compare_value }
        end
      end

      @after.contributors.each do |after_contributor|
        if after_contributor.compare_value.in?(added)
          changes << { action: :added, value: after_contributor.compare_value }
        end
      end

      @differences[:contributors] = changes if changes.count > 0
    end
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable Metrics/ClassLength
