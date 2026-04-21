class BetaFeedbackMailer < ApplicationMailer
  def submission(type:, name:, email:, message:, flow: "", step: "", expected: "", actual: "", browser: "")
    @type     = type
    @name     = name
    @email    = email
    @message  = message
    @flow     = flow
    @step     = step
    @expected = expected
    @actual   = actual
    @browser  = browser

    icon    = @type == "bug" ? "🐛" : "💬"
    subject = if @type == "bug"
                "#{icon} Bug Report — #{@flow.presence || 'Kula HR Beta'}"
              else
                "#{icon} Feedback — Kula HR Beta"
              end

    mail(to: "dwstyagi@gmail.com", reply_to: email, subject: subject)
  end
end
