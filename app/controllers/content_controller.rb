class ContentController < Api::BaseController
  before_action :validate_params!

  def show
    filter = api_request.to_filter
    content = Queries::FindContent.call(filter: filter)

    render json: content.merge(
      organisation_id: params[:organisation_id]
    ).to_json
  end

private

  def api_request
    @api_request ||= Api::ContentRequest.new(permitted_params)
  end

  def permitted_params
    params.permit(:from, :to, :organisation_id, :document_type, :format, :page, :page_size)
  end

  def validate_params!
    unless api_request.valid?
      error_response(
        "validation-error",
        title: "One or more parameters is invalid",
        invalid_params: api_request.errors.to_hash
      )
    end
  end
end
