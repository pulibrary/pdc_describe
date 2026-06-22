# frozen_string_literal: true

class WorkActivity
  # Base renderer for message-type activities
  #
  # Handles rendering of messages with Markdown support and user reference linking
  class BaseMessage < Renderer
    include Rails.application.routes.url_helpers

    USER_REFERENCE = /@[\w]*/ # e.g. @xy123

    # Renders the message body with Markdown and user reference processing
    #
    # @return [String] HTML-rendered message
    def body_html
      text = user_references(@work_activity.message)
      mark_down_to_html(text)
    end

    # Converts Markdown text to HTML
    #
    # @param text_in [String] Markdown text to convert
    # @return [String] HTML output
    def mark_down_to_html(text_in)
      # allow ``` for code blocks (Kramdown only supports ~~~)
      text = text_in.gsub("```", "~~~")
      Kramdown::Document.new(text).to_html
    end

    # Processes user references (@username) and converts them to links
    #
    # @param text_in [String] Text containing user references
    # @return [String] Text with user references converted to HTML links
    def user_references(text_in)
      # convert user references to user links
      text_in.gsub(USER_REFERENCE) do |at_uid|
        uid = at_uid[1..-1]

        if uid
          group = Group.find_by(code: uid)
          if group
            "<a class='message-user-link' title='#{group.title}' href='#{group_path(group)}'>#{group.title}</a>"
          else
            user = User.find_by(uid:)
            user_info = if user
                          user.given_name_safe
                        else
                          uid
                        end
            "<a class='message-user-link' title='#{user_info}' href='#{users_path}/#{uid}'>#{at_uid}</a>"
          end
        else
          Rails.logger.warn("Failed to extract the user ID from #{uid}")
          UNKNOWN_USER
        end
      end
    end
  end
end
