RSpec.describe Healthchecks::DailyMetricsCheck do
  let(:today) { Time.new(2018, 1, 15, 16, 0, 0) }

  around do |example|
    Timecop.freeze(today) { example.run }
  end

  describe '#status' do
    context 'When there are metrics' do
      before { create :metric, dimensions_date: Dimensions::Date.build(Date.yesterday) }

      it 'returns status :ok' do
        expect(subject.status).to eq(:ok)
      end

      it 'returns a detailed message' do
        expect(subject.message).to eq('ETL :: no daily metrics for yesterday')
      end
    end

    context 'When there are no metrics' do
      it 'returns status :ok' do
        expect(subject.status).to eq(:critical)
      end
    end
  end

  describe '#enabled?' do
    around do |example|
      @healthcheck_enabled = ENV['ETL_HEALTHCHECK_ENABLED']
      @healthcheck_hour = ENV['ETL_HEALTHCHECK_ENABLED_FROM_HOUR']
      example.run
      ENV['ETL_HEALTHCHECK_ENABLED'] = @healthcheck_enabled
      ENV['ETL_HEALTHCHECK_ENABLED_FROM_HOUR'] = @healthcheck_hour
    end

    context 'when ETL checks are enabled' do
      before do
        ENV['ETL_HEALTHCHECK_ENABLED'] = '1'
        ENV['ETL_HEALTHCHECK_ENABLED_FROM_HOUR'] = '9'
      end

      context 'within time range' do
        let(:today) { Time.new(2018, 1, 15, 9, 1, 0) }

        it { is_expected.to be_enabled }
      end

      context 'out of time range' do
        let(:today) { Time.new(2018, 1, 15, 1, 0, 0) }

        it { is_expected.to_not be_enabled }
      end
    end

    context 'when ETL checks are not enabled' do
      before do
        ENV.delete 'ETL_HEALTHCHECK_ENABLED'
      end

      let(:today) { Time.new(2018, 1, 15, 20, 0, 0) }

      it { is_expected.to_not be_enabled }
    end
  end
end