module Employees
  class SelfActivationService
    RESEND_COOLDOWN = 15.minutes

    Result = Struct.new(:status, keyword_init: true) do
      def queued?  = status == :queued
      def already_active? = status == :already_active
      def on_cooldown? = status == :on_cooldown
    end

    def self.call(tenant:, email:, employee_code:, date_of_birth:)
      new(tenant: tenant, email: email, employee_code: employee_code, date_of_birth: date_of_birth).call
    end

    def initialize(tenant:, email:, employee_code:, date_of_birth:)
      @tenant        = tenant
      @email         = email.to_s.strip.downcase
      @employee_code = employee_code.to_s.strip.upcase
      @date_of_birth = date_of_birth.to_s.strip
    end

    def call
      employee = find_matching_employee
      return Result.new(status: :queued) if employee.nil? # generic — no enumeration

      return Result.new(status: :already_active) if already_active?(employee)
      return Result.new(status: :on_cooldown)    if on_cooldown?(employee)

      send_invite(employee)
      Result.new(status: :queued)
    end

    private

    def find_matching_employee
      parsed_dob = Date.strptime(@date_of_birth, "%d/%m/%Y") rescue nil
      return nil unless parsed_dob

      ActsAsTenant.with_tenant(@tenant) do
        Employee.find_by(
          "lower(email) = ? AND upper(employee_code) = ? AND date_of_birth = ?",
          @email,
          @employee_code,
          parsed_dob
        )
      end
    end

    def already_active?(employee)
      employee.user&.invitation_accepted_at.present?
    end

    def on_cooldown?(employee)
      return false unless employee.user&.invitation_sent_at.present?

      employee.user.invitation_sent_at > RESEND_COOLDOWN.ago
    end

    def send_invite(employee)
      ActsAsTenant.with_tenant(@tenant) do
        if employee.user.nil?
          ActiveRecord::Base.transaction do
            user = User.create!(
              first_name: employee.first_name,
              last_name:  employee.last_name,
              email:      employee.email,
              password:   SecureRandom.hex(20)
            )
            TenantUser.create!(tenant: @tenant, user: user)
            user.assign_role(:employee)
            employee.update!(user: user)
            user.invite!
          end
        else
          employee.user.invite!
        end
      end
    end
  end
end
