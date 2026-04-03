class ContactsController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  def new
  end

  def create
    @name    = params[:name].to_s.strip
    @email   = params[:email].to_s.strip
    @message = params[:message].to_s.strip

    if @name.blank? || @email.blank? || @message.blank?
      flash.now[:alert] = "Please fill in all fields."
      render :new, status: :unprocessable_entity
      return
    end

    ContactMailer.contact_submission(name: @name, email: @email, message: @message).deliver_later
    redirect_to contact_path, notice: "Message sent! We'll get back to you soon."
  end
end
