# frozen_string_literal: true
xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Princeton Data Commons RSS Feed"
    xml.description "Princeton Data Commons RSS Feed of pending submissions"
    xml.link root_url

    @pending_works.each do |work|
      xml.item do
        xml.title work.title
        xml.url work_url(work, format: "json")
        xml.date_changed work.updated_at
      end
    end
  end
end
