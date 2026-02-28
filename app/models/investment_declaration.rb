class InvestmentDeclaration < ApplicationRecord
  acts_as_tenant :tenant
  belongs_to :tenant
  belongs_to :tax_declaration

  VALID_SECTIONS = %w[80C 80D 80CCD1B 80E 80G 80TTA 24b].freeze

  # Per-section annual deduction limits (nil = no statutory cap)
  SECTION_LIMITS = {
    "80C"     => 150_000,   # PPF, ELSS, LIC, EPF, NSC, tuition fees, home loan principal
    "80D"     => 50_000,    # Medical insurance (25k self + 25k parents; 50k if senior citizen)
    "80CCD1B" => 50_000,    # NPS additional deduction (over and above 80C)
    "80E"     => nil,       # Education loan interest — no limit
    "80G"     => nil,       # Donations — 50% or 100% depending on organisation
    "80TTA"   => 10_000,    # Savings account interest
    "24b"     => 200_000    # Home loan interest (self-occupied)
  }.freeze

  validates :section,         presence: true, inclusion: { in: VALID_SECTIONS }
  validates :description,     presence: true
  validates :declared_amount, numericality: { greater_than: 0 }
end
