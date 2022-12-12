# frozen_string_literal: true

require "diff/lcs"

class SimpleDiff
  def initialize(old_value, new_value)
    old_value ||= ""
    new_value ||= ""
    @changes = Diff::LCS.sdiff(old_value, new_value).chunk(&:action).map do |action, changes|
      {
        action: action,
        old: changes.map(&:old_element).join,
        new: changes.map(&:new_element).join
      }
    end
  end

  def to_html
    @changes.map do |chunk|
      old_ellipsis = chunk[:old].gsub(/((?:\S+\s+){3})(.+)((?:\s+\S+){3})/, '\1...\3')
      new_ellipsis = chunk[:new].gsub(/((?:\S+\s+){3})(.+)((?:\s+\S+){3})/, '\1...\3')
      old_html = CGI.escapeHTML(old_ellipsis)
      new_html = CGI.escapeHTML(new_ellipsis)
      if chunk[:action] == "="
        new_html
      else
        (old_html.empty? ? "" : "<del>#{old_html}</del>") + \
          (new_html.empty? ? "" : "<ins>#{new_html}</ins>")
      end
    end.join
  end
end
