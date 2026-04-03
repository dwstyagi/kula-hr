class ContactMailer < ApplicationMailer
  def contact_submission(name:, email:, message:)
    @name    = name
    @email   = email
    @message = message

    mail(
      to:       "dwstyagi@gmail.com",
      reply_to: email,
      subject:  "New contact from #{name} — Kula HR"
    )
  end
end
