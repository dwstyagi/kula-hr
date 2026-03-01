class PayrollMailerPreview < ActionMailer::Preview
  def processing_complete
    PayrollMailer.processing_complete(payroll_run)
  end

  def processing_complete_with_errors
    errors = [
      { name: "Amit Sharma",  error: "No salary structure assigned" },
      { name: "Ravi Kumar",   error: "Attendance not locked" }
    ]
    PayrollMailer.processing_complete_with_errors(payroll_run, errors)
  end

  def submitted_for_review
    PayrollMailer.submitted_for_review(payroll_run)
  end

  def rejected
    run = payroll_run
    run.rejection_reason = "TDS for Amit Sharma looks incorrect. Please verify the investment declarations."
    PayrollMailer.rejected(run)
  end

  private

  def payroll_run
    PayrollRun.last
  end
end
