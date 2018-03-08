require 'odyssey'

class Importers::QualityMetrics
  attr_reader :content_quality_service, :item_id

  def self.run(*args)
    new(*args).run
  end

  def initialize(item_id)
    @item_id = item_id
    @content_quality_service = ContentQualityService.new
  end

  def run
    item = Dimensions::Item.find(@item_id)

    quality_metrics = content_quality_service.run(item.get_content)
    item.update_attributes(quality_metrics)
  rescue InvalidSchemaError
    do_nothing
  end

private

  def do_nothing; end
end