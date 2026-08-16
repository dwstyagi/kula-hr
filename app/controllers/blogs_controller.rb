class BlogsController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  rescue_from BlogPost::NotFound, with: :post_not_found

  def index
    @posts = BlogPost.published
  end

  def show
    @post = BlogPost.find(params[:slug])
  end

  private

  def post_not_found
    render "errors/not_found", status: :not_found
  end
end
