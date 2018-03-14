class Content::Parsers::StatisticsAnnouncement
  def parse(json)
    html = []
    html << json.dig("description")
    html << json.dig("details", "display_date")
    html << json.dig("details", "state")
    html.join(" ")
  end
end
Content::Parser.register('statistics_announcement',
  Content::Parsers::StatisticsAnnouncement.new)
