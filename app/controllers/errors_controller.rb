class ErrorsController < ApplicationController
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  def not_found
    render status: :not_found
  end
end
