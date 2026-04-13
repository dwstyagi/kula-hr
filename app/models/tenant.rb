class Tenant < ApplicationRecord
  has_paper_trail

  has_many :tenant_users, dependent: :destroy
  has_many :users, through: :tenant_users
  has_many :departments, dependent: :destroy
  has_many :designations, dependent: :destroy
  has_many :salary_components, dependent: :destroy
  has_many :salary_structures, dependent: :destroy
  has_many :employee_salaries, dependent: :destroy
  has_many :leave_types, dependent: :destroy
  has_many :holidays, dependent: :destroy
  has_many :professional_tax_slabs, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_one :payroll_setting, dependent: :destroy
  has_many :payroll_runs, dependent: :destroy

  RESERVED_SUBDOMAINS = %w[www admin api app mail ftp smtp pop imap blog support help
                           status assets cdn static media platform dashboard].freeze

  TRIAL_EMPLOYEE_LIMIT = 50
  TRIAL_PAYROLL_RUN_LIMIT = 3
  WRITE_ALLOWED_STATUSES = %w[trial active].freeze

  validates :name, presence: true
  validates :subdomain, presence: true,
                         uniqueness: { case_sensitive: false },
                         length: { minimum: 3, maximum: 63 },
                         format: { with: /\A[a-z\d](?:[a-z\d-]*[a-z\d])?\z/,
                                   message: "must start and end with a letter or number, and can contain hyphens" },
                         exclusion: { in: RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :gstin, format: { with: /\A\d{2}[A-Z]{5}\d{4}[A-Z]\d[Z][A-Z\d]\z/, message: "is not a valid GSTIN" },
                    allow_blank: true
  validates :pan, format: { with: /\A[A-Z]{5}\d{4}[A-Z]\z/, message: "is not a valid PAN" },
                  allow_blank: true
  validates :status, inclusion: { in: %w[trial active suspended cancelled] }

  scope :active, -> { where(status: "active") }
  scope :trial, -> { where(status: "trial") }
  scope :suspended, -> { where(status: "suspended") }

  ACTIVATION_TOKEN_VALIDITY = 1.hour
  INVITE_TOKEN_VALIDITY = 24.hours

  before_validation :normalize_subdomain

  def trial?            = status == "trial"
  def active?           = status == "active"
  def suspended?        = status == "suspended"

  def write_allowed?
    return false unless WRITE_ALLOWED_STATUSES.include?(status)
    return false if trial_payroll_runs_exhausted?
    true
  end

  def at_employee_limit?
    trial? && employees.count >= TRIAL_EMPLOYEE_LIMIT
  end

  def trial_payroll_runs_used
    payroll_runs.where(status: %w[approved paid]).count
  end

  def trial_payroll_runs_exhausted?
    trial? && trial_payroll_runs_used >= TRIAL_PAYROLL_RUN_LIMIT
  end

  def generate_activation_token!
    update!(
      activation_token: SecureRandom.urlsafe_base64(32),
      activation_token_expires_at: ACTIVATION_TOKEN_VALIDITY.from_now
    )
  end

  def activation_token_valid?
    activation_token.present? && activation_token_expires_at&.future?
  end

  def revoke_activation_token!
    update!(activation_token: nil, activation_token_expires_at: nil)
  end

  def generate_invite_token!
    update!(
      invite_token: SecureRandom.urlsafe_base64(32),
      invite_token_expires_at: INVITE_TOKEN_VALIDITY.from_now
    )
  end

  def invite_token_valid?
    invite_token.present? && invite_token_expires_at&.future?
  end

  def revoke_invite_token!
    update!(invite_token: nil, invite_token_expires_at: nil)
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain.to_s.strip.downcase
  end
end
