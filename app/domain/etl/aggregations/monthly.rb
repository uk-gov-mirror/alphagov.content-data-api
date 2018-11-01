class Etl::Aggregations::Monthly
  def self.process(*args)
    new(*args).process
  end

  def initialize(date: Date.yesterday)
    @date = date
  end

  def process
    ::Aggregations::MonthlyMetric.where(dimensions_month_id: month).delete_all
    ActiveRecord::Base.connection.execute(query)
  end

private

  attr_reader :date

  def from
    date.beginning_of_month
  end

  def to
    date.end_of_month
  end

  def month
    Dimensions::Month.build(from)
  end

  def query
    <<~SQL
      INSERT INTO aggregations_monthly_metrics (
        dimensions_month_id,
        dimensions_edition_id,
        pviews,
        upviews,
        entrances,
        searches,
        bounce_rate,
        feedex,
        satisfaction,
        useful_yes,
        useful_no,
        exits,
        avg_page_time,
        updated_at,
        created_at
      )
      SELECT '#{month.id}',
        max(dimensions_edition_id),
        sum(pviews),
        sum(upviews),
        sum(entrances),
        sum(searches),
        sum(bounce_rate),
        sum(feedex),
        sum(satisfaction),
        sum(useful_yes),
        sum(useful_no),
        sum(exits),
        sum(avg_page_time),
        now(),
        now()
      FROM facts_metrics
      INNER JOIN dimensions_dates ON dimensions_dates.date = facts_metrics.dimensions_date_id
      INNER JOIN dimensions_editions ON dimensions_editions.id = facts_metrics.dimensions_edition_id
      WHERE dimensions_date_id >= '#{from}' AND dimensions_date_id <= '#{to}'
      GROUP BY warehouse_item_id
    SQL
  end
end
