class LeaveMailer < ApplicationMailer
  def encashment_reminder(employee, leave_type, eligible_days)
    @employee      = employee
    @leave_type    = leave_type
    @eligible_days = eligible_days

    mail(
      to:      employee.email,
      subject: "Action Required: #{eligible_days.to_i} #{leave_type.name} Day(s) Eligible for Encashment"
    )
  end

  def encashment_approved(encashment_request)
    @request   = encashment_request
    @employee  = encashment_request.employee
    @leave_type = encashment_request.leave_type

    mail(
      to:      @employee.email,
      subject: "Leave Encashment Approved — ₹#{number_with_delimiter(@request.encashment_amount.to_i)}"
    )
  end

  def encashment_rejected(encashment_request)
    @request    = encashment_request
    @employee   = encashment_request.employee
    @leave_type = encashment_request.leave_type

    mail(
      to:      @employee.email,
      subject: "Leave Encashment Request — Update"
    )
  end
end
