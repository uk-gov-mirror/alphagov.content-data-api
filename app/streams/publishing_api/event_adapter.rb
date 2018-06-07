module PublishingAPI
  class EventAdapter
    def self.to_dimension_item(*args)
      new(*args).to_dimension_item
    end

    def initialize(event)
      @event = event
    end

    def to_dimension_item
      Dimensions::Item.new(
        content_id: event.payload.fetch('content_id'),
        base_path: event.payload.fetch('base_path'),
        publishing_api_payload_version: event.payload.fetch('payload_version'),
        document_type: event.payload.fetch('document_type'),
        locale: event.payload['locale'],
        title: event.payload['title'],
        content_purpose_document_supertype: event.payload['content_purpose_document_supertype'],
        content_purpose_supergroup: event.payload['content_purpose_supergroup'],
        content_purpose_subgroup: event.payload['content_purpose_subgroup'],
        first_published_at: parse_time('first_published_at'),
        primary_organisation_content_id: primary_organisation['content_id'],
        primary_organisation_title: primary_organisation['title'],
        primary_organisation_withdrawn: primary_organisation['withdrawn'],
        public_updated_at: parse_time('public_updated_at'),
        latest: true,
        raw_json: event.payload.to_json,
      )
    end

    def primary_organisation
      primary_org = event.payload.dig('expanded_links', 'primary_publishing_organisation') || []
      primary_org.any? ? primary_org[0] : {}
    end

  private

    attr_reader :event

    def parse_time(attribute_name)
      event.payload.fetch(attribute_name, nil)
    end
  end
end
