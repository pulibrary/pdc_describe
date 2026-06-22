# frozen_string_literal: true

class WorkActivity
  # Base renderer class for WorkActivity instances
  #
  # Provides common functionality for rendering work activities as HTML,
  # including date formatting and user information display.
  class Renderer
    UNKNOWN_USER = "Unknown user outside the system"
    DATE_TIME_FORMAT = "%B %d, %Y %H:%M"
    DATE_FORMAT = "%B %d, %Y"
    SORTABLE_DATE_TIME_FORMAT = "%Y-%m-%d %H:%M"

    # @param work_activity [WorkActivity] The work activity to render
    def initialize(work_activity)
      @work_activity = work_activity
    end

    # Renders the complete activity as HTML
    #
    # @return [String] HTML representation of the activity
    def to_html
      title_html + "<span class='message-html'>#{body_html.chomp}</span>"
    end

    # Renders the user who created the activity
    #
    # @return [String] HTML-safe string with user information
    def created_by_user_html
      return UNKNOWN_USER unless @work_activity.created_by_user

      "#{@work_activity.created_by_user.given_name_safe} (@#{@work_activity.created_by_user.uid})"
    end

    # Renders the creation date in a sortable format
    #
    # @return [String] Formatted date string for sorting
    def created_sortable_html
      @work_activity.created_at.time.strftime(SORTABLE_DATE_TIME_FORMAT)
    end

    # Renders creation and update dates, with backdating indicator
    #
    # @return [String] Formatted date string with optional backdating notice
    def created_updated_html
      created = @work_activity.created_at.time.strftime(DATE_TIME_FORMAT)
      updated = @work_activity.updated_at.time.strftime(DATE_TIME_FORMAT)
      created_date = @work_activity.created_at.time.strftime(DATE_FORMAT)
      updated_date = @work_activity.updated_at.time.strftime(DATE_FORMAT)
      if created_date == updated_date
        created
      else
        "#{created} (backdated event created #{updated})"
      end
    end

    # Renders the title section of the activity
    #
    # @return [String] HTML title element
    def title_html
      "<span class='activity-history-title'>#{created_updated_html} by #{created_by_user_html}</span>"
    end

    # Renders the body content of the activity
    # Should be overridden by subclasses
    #
    # @return [String] HTML body content
    def body_html
      raise NotImplementedError, "Subclasses must implement #body_html"
    end
  end
end
