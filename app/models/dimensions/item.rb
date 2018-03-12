require 'json'


class Dimensions::Item < ApplicationRecord
  validates :content_id, presence: true


  scope :dirty_before, ->(date) do
    where('updated_at < ?', date).where(dirty: true)
  end

  def get_content
    return if raw_json.blank?
    extract_by_schema_type(raw_json)
  end

  def new_version
    new_version = self.dup
    new_version.assign_attributes(latest: true, dirty: false)
    new_version
  end

  def dirty!
    update_attributes!(dirty: true)
  end

  def gone!
    update_attributes(status: 'gone')
  end

  def self.create_empty(content_id, base_path)
    create(
      content_id: content_id,
      base_path: base_path,
      latest: true,
      dirty: true
    )
  end

private

  VALID_SCHEMA_TYPES = %w[
    answer
    case_study
    consultation
    corporate_information_page
    detailed_guide
    document_collection
    email_alert_signup
    fatality_notice
    finder_email_signup
    help
    hmrc_manual_section
    html_publication
    location_transaction
    manual
    manual_section
    news_article
    publication
    service_manual_guide
    service_manual_topic
    simple_smart_answer
    specialist_document
    speech
    statistical_data_set
    take_part
    topical_event_about_page
    transaction
    working_group
    world_location_news_article
  ].freeze

  def extract_by_schema_type(json)
    schema = json.dig("schema_name")
    if Parsers::ContentExtractors.for_schema(schema)
      html = Parsers::ContentExtractors.for_schema(schema).parse(json)
      return parse_html(html)
    end

    if schema.nil? || !VALID_SCHEMA_TYPES.include?(schema)
      raise InvalidSchemaError, "Schema does not exist: #{schema}"
    end

    html =
      case schema
      when 'email_alert_signup'
        extract_email_signup(json)
      when 'finder_email_signup'
        extract_finder(json)
      when 'location_transaction'
        extract_location_transaction(json)
      when 'service_manual_topic'
        extract_manual_topic(json)
      else
        extract_main(json)
      end
    parse_html(html)
  end

  def extract_email_signup(json)
    html = []
    json.dig("details", "breadcrumbs").each do |crumb|
      html << crumb["title"]
    end
    html << json.dig("details", "summary")
    html.join(" ")
  end

  def extract_finder(json)
    html = []
    json.dig("details", "email_signup_choice").each do |choice|
      html << choice["radio_button_name"]
    end
    html << json.dig("description")
    html.join(" ")
  end

  def extract_location_transaction(json)
    html = []
    html << json.dig("details", "introduction")
    html << json.dig("details", "need_to_know")
    html << json.dig("details", "more_information")
    html.join(" ")
  end

  def extract_manual_topic(json)
    html = []
    html << json.dig("description")
    json.dig("details", "groups").each do |group|
      html << group["name"]
      html << group["description"]
    end
    html.join(" ")
  end

  def extract_main(json)
    json.dig("details", "body")
  end

  def parse_html(html)
    return if html.nil?
    html.delete!("\n")
    Nokogiri::HTML.parse(html).text
  end
end

class InvalidSchemaError < StandardError;
end
