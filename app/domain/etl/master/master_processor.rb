class Etl::Master::MasterProcessor
  include Concerns::Traceable

  def self.process(*args)
    new(*args).process
  end

  def initialize(date: Date.yesterday)
    @date = date
  end

  def process
    raise DuplicateDateError if already_run?

    time(process: :master) do
      Etl::Master::MetricsProcessor.process(date: date)
      Etl::GA::ViewsAndNavigationProcessor.process(date: date)
      Etl::GA::UserFeedbackProcessor.process(date: date)
      Etl::GA::InternalSearchProcessor.process(date: date)
      Etl::Feedex::Processor.process(date: date)
    end
  end

  def already_run?
    Facts::Metric.where(dimensions_date_id: date).any?
  end

private

  attr_reader :date

  class DuplicateDateError < StandardError;
  end
end