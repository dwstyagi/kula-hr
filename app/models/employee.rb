class Employee < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :user, optional: true
  belongs_to :department, optional: true
  belongs_to :designation, optional: true
  belongs_to :reporting_manager, class_name: "Employee", optional: true

  has_many :direct_reports, class_name: "Employee", foreign_key: :reporting_manager_id, dependent: :nullify, inverse_of: :reporting_manager
  has_many :employee_salaries, dependent: :destroy

  has_paper_trail

  EMPLOYMENT_STATUSES = %w[active probation notice_period resigned terminated].freeze
  GENDERS = %w[male female other].freeze

  # Validations
  validates :employee_code, presence: true, uniqueness: { scope: :tenant_id }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true,
                    uniqueness: { scope: :tenant_id, case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :joining_date, presence: true
  validates :employment_status, presence: true, inclusion: { in: EMPLOYMENT_STATUSES }
  validates :gender, inclusion: { in: GENDERS }, allow_blank: true
  validates :pan_number, format: { with: /\A[A-Z]{5}\d{4}[A-Z]\z/, message: "is not a valid PAN" }, allow_blank: true
  validates :aadhaar_number, format: { with: /\A\d{12}\z/, message: "must be 12 digits" }, allow_blank: true
  validates :pincode, format: { with: /\A\d{6}\z/, message: "must be 6 digits" }, allow_blank: true

  # Scopes
  scope :active, -> { where(employment_status: "active") }
  scope :probation, -> { where(employment_status: "probation") }
  scope :resigned, -> { where(employment_status: "resigned") }

  # Callbacks
  before_validation :generate_employee_code, on: :create

  def full_name
    "#{first_name} #{last_name}"
  end

  def current_salary
    employee_salaries.current.first
  end

  def active?
    employment_status == "active"
  end

  private

  def generate_employee_code
    return if employee_code.present?

    last_code = self.class.where(tenant_id: tenant_id)
                    .order(employee_code: :desc)
                    .pick(:employee_code)

    next_number = if last_code&.match?(/\AEMP\d+\z/)
                    last_code.delete_prefix("EMP").to_i + 1
    else
      1
    end

    self.employee_code = "EMP#{next_number.to_s.rjust(4, '0')}"
  end
end
