require 'govuk_message_queue_consumer/test_helpers'

RSpec.describe PublishingAPI::Consumer do
  include PublishingEventProcessingSpecHelper
  let(:subject) { described_class.new }

  it 'does not notify error if message is missing `locale`' do
    message = build(:message)
    message.payload.except!('locale')

    expect(GovukError).not_to receive(:notify)
    subject.process(message)
  end

  it 'grows the dimension with update events' do
    expect {
      subject.process(build(:message))
    }.to change(Dimensions::Edition, :count).by(1)
  end

  it 'is idempotent' do
    message = build :message

    expect {
      subject.process(message)
      subject.process(message)
    }.to change(Dimensions::Edition, :count).by(1)
  end

  it 'ignores old events' do
    message = build :message, base_path: '/base-path', attributes: { 'payload_version' => 2 }
    message2 = build :message, payload: message.payload, attributes: { 'payload_version' => 1 }

    expect {
      subject.process(message)
      subject.process(message2)
    }.to change(Dimensions::Edition, :count).by(1)
    expect(Dimensions::Edition.first).to have_attributes(publishing_api_payload_version: 2)
    expect(Dimensions::Edition.first).to have_attributes(latest: true)
  end


  it 'does not grow the dimension if the event carries no changes in an attribute' do
    message = build :message, base_path: '/base-path', attributes: { 'payload_version' => 2 }
    message2 = build :message, payload: message.payload.dup
    message2.payload['payload_version'] = 4

    expect {
      subject.process(message)
      subject.process(message2)
    }.to change(Dimensions::Edition, :count).by(1)
  end

  context 'when the event carries a change' do
    it 'deprecates old editions' do
      message = build :message, base_path: '/base-path', attributes: { 'payload_version' => 2 }
      message2 = build :message, payload: message.payload.dup
      message2.payload['payload_version'] = 4
      message2.payload['title'] = 'updated-title'

      expect {
        subject.process(message)
        subject.process(message2)
      }.to change(Dimensions::Edition, :count).by(2)

      expect(Dimensions::Edition.find_by(publishing_api_payload_version: 2)).to have_attributes(latest: false)
      expect(Dimensions::Edition.find_by(publishing_api_payload_version: 4)).to have_attributes(latest: true)
    end

    it 'grows the dimension' do
      message = build :message, base_path: '/base-path', attributes: { 'payload_version' => 2 }
      message2 = build :message, payload: message.payload.deep_dup
      message2.payload['payload_version'] = 4
      message2.payload['details']['body'] = '<p>different content</p>'
      expect {
        subject.process(message)
        subject.process(message2)
      }.to change(Dimensions::Edition, :count).by(2)
    end

    it 'updates the attributes correctly' do
      message = build :message, base_path: '/base-path', attributes: message_attributes
      message.payload['details']['body'] = '<p>some content</p>'
      subject.process(message)
      latest_edition = Dimensions::Edition.where(base_path: '/base-path', latest: true).first
      expect(latest_edition).to have_attributes(expected_attributes(content_id: message.payload['content_id']))
    end

    it 'assigns the same warehouse_item_id to the new edition' do
      content_id = SecureRandom.uuid
      message = build :message,
        base_path: '/base-path',
        content_id: content_id,
        attributes: { 'payload_version' => 2 }
      message2 = build :message,
        content_id: content_id,
        payload: message.payload.deep_dup
      message2.payload['payload_version'] = 4
      message2.payload['details']['body'] = '<p>different content</p>'
      subject.process(message)
      subject.process(message2)
      warehouse_ids = Dimensions::Edition.where(base_path: '/base-path').pluck(:warehouse_item_id)
      expect(warehouse_ids.uniq).to eq(["#{content_id}:en"])
    end
  end

  context 'when the base path has changed' do
    let(:content_id) { SecureRandom.uuid }
    let(:locale) { 'en' }
    let(:warehouse_item_id) { "#{content_id}:#{locale}" }
    let(:new_base_path) { '/new/base/path' }

    it 'creates the new edition with the warehouse_item_id of the old edition' do
      create :edition,
        base_path: '/old/base/path',
        content_id: content_id,
        locale: locale,
        warehouse_item_id: warehouse_item_id,
        latest: true,
        publishing_api_payload_version: 2
      message = build :message,
        base_path: new_base_path,
        content_id: content_id,
        locale: locale,
        payload_version: 3

      subject.process(message)

      new_edition = Dimensions::Edition.find_by(content_id: content_id,
        locale: locale,
        latest: true)
      expect(new_edition).to have_attributes(
        warehouse_item_id: warehouse_item_id,
        base_path: new_base_path
      )
    end
  end

  describe 'all schemas' do
    before do
      allow(GovukError).to receive(:notify)
    end

    SchemasIterator.each_schema do |schema_name, schema|
      payload = GovukSchemas::RandomExample.new(schema: schema).payload
      unless %w{travel_advice guide}.include?(schema_name) || schema_name.include?('placeholder')

        %w{major minor links republish unpublish}.each do |update_type|
          it "handles event for: `#{schema_name}` with no errors for a `#{update_type}` update" do
            message = build(:message, payload: payload, routing_key: "#{schema_name}.#{update_type}")

            subject.process(message)

            expect(GovukError).not_to have_received(:notify)
          end
        end
      end
    end
  end
end
