# frozen_string_literal: true
xml.instruct! :xml, version: "1.0"
xml.rss version: "2.0" do
  xml.channel do
    xml.title "Princeton Data Commons RSS Feed"
    xml.description "Princeton Data Commons RSS Feed of approved submissions"
    xml.link root_url

    @works.each do |work|
      xml.item do
        xml.title work.title
        xml.url datacite_work_url(work)
        xml.date_changed work.updated_at
      end
    end
  end
end
