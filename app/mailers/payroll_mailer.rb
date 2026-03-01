class PayrollMailer < ApplicationMailer
  # Sent to the HR who initiated the run — all employees processed cleanly
  def processing_complete(payroll_run)
    @payroll_run = payroll_run
    @tenant      = payroll_run.tenant

    hr_emails = hr_email_addresses(payroll_run)
    return if hr_emails.empty?

    mail(
      to:      hr_emails,
      subject: "Payroll Processed — #{payroll_run.period_label} (#{@tenant.company_name})"
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
      subject: "Payroll Processed with Errors — #{payroll_run.period_label} (#{@tenant.company_name})"
    )
  end

  private

  def hr_email_addresses(payroll_run)
    [ payroll_run.initiated_by.email ].compact
  end
end
