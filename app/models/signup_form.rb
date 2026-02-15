class SignupForm
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :company_name, :string
  attribute :subdomain, :string
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :password, :string
  attribute :password_confirmation, :string
  attribute :state, :string

  validates :company_name, presence: true
  validates :subdomain, presence: true,
                         length: { minimum: 3, maximum: 63 },
                         format: { with: /\A[a-z\d](?:[a-z\d-]*[a-z\d])?\z/,
                                   message: "must start and end with a letter or number, and can contain hyphens" },
                         exclusion: { in: Tenant::RESERVED_SUBDOMAINS, message: "is reserved" }
  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, confirmation: true
  validates :password_confirmation, presence: true
  validates :state, presence: true
  validate :subdomain_available

  private

  def subdomain_available
    return if subdomain.blank?

    errors.add(:subdomain, "is already taken") if Tenant.exists?(subdomain: subdomain.downcase)
  end
end
