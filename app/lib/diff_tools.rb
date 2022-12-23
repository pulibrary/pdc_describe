# frozen_string_literal: true

require "diff/lcs"

module DiffTools
  class SimpleDiff
    def initialize(old_value, new_value)
      old_value = old_value.to_s.split /\b/
      new_value = new_value.to_s.split /\b/
      @changes = ::Diff::LCS.sdiff(old_value, new_value).chunk(&:action).map do |action, changes|
        {
          action: action,
          old: changes.map(&:old_element).join,
          new: changes.map(&:new_element).join
        }
      end
    end

    def to_html
      @changes.map do |chunk|
        old_html = DiffTools.value_to_html(chunk[:old])
        new_html = DiffTools.value_to_html(chunk[:new])
        if chunk[:action] == "="
          new_html
        else
          (old_html.empty? ? "" : "<del>#{old_html}</del>") + \
            (new_html.empty? ? "" : "<ins>#{new_html}</ins>")
        end
      end.join
    end
  end

  def self.value_to_html(value)
    too_many_words_re = /
      ((?:\S+\s+){3}) # group 1: Three words, including trailing space
      (.+)            # group 2: Drop this
      ((?:\s+\S+){3}) # group 3: Three words, including leading space
    /x
    ellipsis = value.gsub(too_many_words_re, '\1...\3')
    CGI.escapeHTML(ellipsis)
  end
end
