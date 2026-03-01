class PayrollMailer < ApplicationMailer
  # Sent to the HR who initiated the run — all employees processed cleanly
  def processing_complete(payroll_run)
    @payroll_run = payroll_run
    @tenant      = payroll_run.tenant

    hr_emails = hr_email_addresses(payroll_run)
    return if hr_emails.empty?

    mail(
      to:      hr_emails,
      subject: "Payroll Processed — #{payroll_run.period_label} (#{@tenant.name})"
    )
  end

  # Sent when some employees were skipped due to errors
  def processing_complete_with_errors(payroll_run, errors)
    @payroll_run = payroll_run
    @tenant      = payroll_run.tenant
    @errors      = errors

    hr_emails = hr_email_addresses(payroll_run)
    return if hr_emails.empty?

    mail(
      to:      hr_emails,
      subject: "Payroll Processed with Errors — #{payroll_run.period_label} (#{@tenant.name})"
    )
  end

  # Sent to Super Admins when HR submits payroll for review
  def submitted_for_review(payroll_run)
    @payroll_run = payroll_run
    @tenant      = payroll_run.tenant

    admin_emails = super_admin_email_addresses(payroll_run)
    return if admin_emails.empty?

    mail(
      to:      admin_emails,
      subject: "Payroll Awaiting Approval — #{payroll_run.period_label} (#{@tenant.name})"
    )
  end

  # Sent to the HR who initiated the run when it is rejected
  def rejected(payroll_run)
    @payroll_run = payroll_run
    @tenant      = payroll_run.tenant

    hr_emails = hr_email_addresses(payroll_run)
    return if hr_emails.empty?

    mail(
      to:      hr_emails,
      subject: "Payroll Rejected — #{payroll_run.period_label} (#{@tenant.name})"
    )
  end

  private

  def hr_email_addresses(payroll_run)
    [ payroll_run.initiated_by.email ].compact
  end

  def super_admin_email_addresses(payroll_run)
    ActsAsTenant.with_tenant(payroll_run.tenant) do
      User.with_role(:super_admin).pluck(:email)
    end
  end
end
