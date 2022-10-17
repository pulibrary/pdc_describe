# frozen_string_literal: true

# rubocop:disable Metrics/PerceivedComplexity
# rubocop:disable Metrics/CyclomaticComplexity
# rubocop:disable Metrics/AbcSize
# rubocop:disable Metrics/ClassLength
# rubocop:disable Metrics/MethodLength
# rubocop:disable Metrics/BlockLength
class ResourceCompare
  attr_reader :differences

  def initialize(before, after)
    @before = before
    @after = after
    @differences = {}
    compare_resources
  end

  private

    def compare_resources
      compare_titles
      compare_creators
      compare_contributors
      compare_simple_values
      compare_rights
      compare_keywords
    end

    ##
    # Compares simple values between the two resources.
    def compare_simple_values
      field_names = [:description, :publisher, :publication_year, :resource_type, :resource_type_general,
                     :doi, :ark, :version_number, :collection_tags]

      field_names.each do |field_name|
        before_value = @before.send(field_name)
        after_value = @after.send(field_name)
        if before_value != after_value
          @differences[field_name] = { action: :changed, from: before_value, to: after_value }
        end
      end
    end

    def compare_rights
      before_value = @before.rights&.name
      after_value = @after.rights&.name
      if before_value != after_value
        @differences[:rights] = { action: :changed, from: before_value, to: after_value }
      end
    end

    def compare_keywords
      before_value = @before.keywords.join(",")
      after_value = @after.keywords.join(",")
      if before_value != after_value
        @differences[:keywords] = { action: :changed, from: before_value, to: after_value }
      end
    end

    ##
    # Compares the titles between the two resources. This is a bit tricky because we support many
    # titles and the title itself is an object with two properties (title and title_type)
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

    ##
    # Compares the creators between the two resources. This is a bit tricky because we support many
    # creators and the creator objects have many properties.
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

    ##
    # Compares the contributors between the two resources. This is a bit tricky because we support many
    # contributors and the contributor objects have many properties.
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
end
# rubocop:enable Metrics/PerceivedComplexity
# rubocop:enable Metrics/CyclomaticComplexity
# rubocop:enable Metrics/AbcSize
# rubocop:enable Metrics/ClassLength
# rubocop:enable Metrics/MethodLength
# rubocop:enable Metrics/BlockLength
