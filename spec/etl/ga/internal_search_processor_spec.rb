require "rails_helper"
require "gds-api-adapters"

RSpec.describe GA::InternalSearchProcessor do
  subject { described_class }

  let!(:item1) { create :dimensions_item, base_path: "/path1", latest: true }
  let!(:item2) { create :dimensions_item, base_path: "/path2", latest: true }

  let(:date) { Date.new(2018, 2, 20) }
  let(:dimensions_date) { Dimensions::Date.for(date) }

  context "When the base_path matches the GA path" do
    before { allow(GA::InternalSearchService).to receive(:find_in_batches).and_yield(ga_response) }

    it "updates the facts with GA metrics" do
      fact1 = create :metric, dimensions_item: item1, dimensions_date: dimensions_date
      fact2 = create :metric, dimensions_item: item2, dimensions_date: dimensions_date

      described_class.process(date: date)

      expect(fact1.reload).to have_attributes(number_of_internal_searches: 1)
      expect(fact2.reload).to have_attributes(number_of_internal_searches: 2)
    end

    it "does not update metrics for other days" do
      fact1 = create :metric, dimensions_item: item1, dimensions_date: dimensions_date, number_of_internal_searches: 20

      day_before = date - 1
      described_class.process(date: day_before)

      expect(fact1.reload).to have_attributes(number_of_internal_searches: 20)
    end

    it "does not update metrics for other items" do
      item = create :dimensions_item, base_path: "/non-matching-path", latest: true
      fact = create :metric, dimensions_item: item, dimensions_date: dimensions_date, number_of_internal_searches: 99

      described_class.process(date: date)

      expect(fact.reload).to have_attributes(number_of_internal_searches: 99)
    end

    it "deletes the events that matches the base_path of an item if it has number of internal search data" do
      item2.destroy
      create :metric, dimensions_item: item1, dimensions_date: dimensions_date

      described_class.process(date: date)

      expect(Events::GA.count).to eq(1)
    end

    it "does not delete the events that match the base_path of an item if it does not have number of internal search data" do
      create :ga_event, :with_views, date: date, page_path: item1.base_path
      create :metric, dimensions_item: item1, dimensions_date: dimensions_date

      described_class.process(date: date)

      expect(Events::GA.count).to eq(2)
    end

    context "when there are events from other days" do
      before do
        create :ga_event, :with_number_of_internal_searches, date: date - 1, page_path: '/path1'
        create :ga_event, :with_number_of_internal_searches, date: date - 2, page_path: '/path1'
      end

      it "only updates metrics for the current day" do
        fact1 = create :metric, dimensions_item: item1, dimensions_date: dimensions_date

        described_class.process(date: date)

        expect(fact1.reload).to have_attributes(number_of_internal_searches: 1)
      end

      it "deletes events for the current day if it has number of internal searches" do
        create :metric, dimensions_item: item1, dimensions_date: dimensions_date
        create :metric, dimensions_item: item2, dimensions_date: dimensions_date
        described_class.process(date: date)

        expect(Events::GA.count).to eq(2)
      end

      it "does not delete events that are not from the current day" do
        create :metric, dimensions_item: item1, dimensions_date: dimensions_date
        described_class.process(date: date)

        expect(Events::GA.count).to eq(3)
      end
    end
  end

  context 'when page_path starts "/https://www.gov.uk"' do
    before do
      allow(GA::InternalSearchService).to receive(:find_in_batches)
      .and_yield(ga_response_with_govuk_prefix)
    end
    include_examples "transform path examples"
  end

private

  def ga_response
    [
      {
        'page_path' => '/path1',
        'number_of_internal_searches' => 1,
        'date' => '2018-02-20',
        'process_name' => 'number_of_internal_searches'
      },
      {
        'page_path' => '/path2',
        'number_of_internal_searches' => 2,
        'date' => '2018-02-20',
        'process_name' => 'number_of_internal_searches'
      },
    ]
  end

  def ga_response_with_govuk_prefix
    [
      {
        'page_path' => '/https://www.gov.uk/path1',
        'number_of_internal_searches' => 1,
        'date' => '2018-02-20',
        'process_name' => 'number_of_internal_searches'
      },
      {
        'page_path' => '/path2',
        'number_of_internal_searches' => 2,
        'date' => '2018-02-20',
        'process_name' => 'number_of_internal_searches'
      },
    ]
  end
end