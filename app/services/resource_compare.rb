# frozen_string_literal: true

class ResourceCompare
  def initialize(before, after)
    @before = before
    @after = after
    @result = {}
  end

  def compare()
    compare_titles()
    compare_creators()
    # :contributors
    compare_single_values()
    @result
  end

  def compare_single_values()
    field_names = [:description, :publisher, :publication_year, :resource_type, :resource_type_general,
      :doi, :ark, :version_number, :collection_tags]

    field_names.each do |field_name|
      before_value = @before.send(field_name)
      after_value = @after.send(field_name)
      if before_value != after_value
        @result[field_name] = {action: :changed, from: before_value, to: after_value}
      end
    end

    before_value = @before.rights&.name
    after_value = @after.rights&.name
    if before_value != after_value
      @result[:rights] = {action: :changed, from: before_value, to: after_value}
    end

    before_value = @before.keywords.join(',')
    after_value = @after.keywords.join(',')
    if before_value != after_value
      @result[:keywords] = {action: :changed, from: before_value, to: after_value}
    end
  end

  def compare_titles()
    changes = []
    keys_before = @before.titles.map(&:title_type)
    keys_after = @after.titles.map(&:title_type)

    removed = keys_before - keys_after
    added = keys_after - keys_before
    common = (keys_before + keys_after).uniq - removed - added

    @before.titles.each do |before_title|
      case
      when before_title.title_type.in?(common)
        after_title = @after.titles.find {|t| t.title_type == before_title.title_type }
        if before_title.title != after_title.title
          changes << {action: :changed, from: before_title.title, to: after_title.title}
        end
      when before_title.title_type.in?(removed)
        changes << {action: :removed, value: before_title.title}
      end
    end

    @after.titles.each do |after_title|
      if after_title.title_type.in?(added)
        changes << {action: :added, value: after_title.title}
      end
    end

    @result[:titles] = changes if changes.count > 0
  end

  def compare_creators()
    changes = []
    keys_before = @before.creators.map(&:compare_value)
    keys_after = @after.creators.map(&:compare_value)

    removed = keys_before - keys_after
    added = keys_after - keys_before
    common = (keys_before + keys_after).uniq - removed - added

    @before.creators.each do |before_creator|
      case
      when before_creator.compare_value.in?(common)
        after_creator = @after.creators.find {|c| c.compare_value == before_creator.compare_value }
        if before_creator.compare_value != after_creator.compare_value
          changes << {action: :changed, from: before_creator.compare_value, to: after_creator.compare_value}
        end
      when before_creator.compare_value.in?(removed)
        changes << {action: :removed, value: before_creator.compare_value}
      end
    end

    @after.creators.each do |after_creator|
      if after_creator.compare_value.in?(added)
        changes << {action: :added, value: after_creator.compare_value}
      end
    end

    @result[:creators] = changes if changes.count > 0
  end
end
