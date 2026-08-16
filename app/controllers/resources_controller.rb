class ResourcesController < ApplicationController
  skip_before_action :set_current_tenant_from_subdomain
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  layout "marketing"

  LAST_REVIEWED = Date.new(2026, 8, 10)

  OFFICIAL_SOURCES = {
    epfo: {
      label: "Employees' Provident Fund Organisation",
      url: "https://www.epfindia.gov.in/site_en/FAQ.php/index.php"
    },
    esic: {
      label: "Employees' State Insurance Corporation",
      url: "https://esic.gov.in/attachments/citizens_charter/citizens_charter_1751627535.pdf"
    },
    income_tax: {
      label: "Income Tax Department",
      url: "https://www.incometax.gov.in/iec/foportal/help/all-topics/e-filing-services/tax-payments-faq?mobile-app=1"
    }
  }.freeze

  COMPLIANCE_SOURCES = {
    epfo: {
      label: "EPFO contribution payment guidance",
      url: "https://www.epfindia.gov.in/site_en/FAQ.php?id=sm36_index"
    },
    esic: {
      label: "ESI (General) Regulations, 1950",
      url: "https://www.esic.gov.in/attachments/actfile/ec890b0f0333e87d22533a0d22194370.pdf"
    },
    income_tax: OFFICIAL_SOURCES.fetch(:income_tax)
  }.freeze

  PROFESSIONAL_TAX_STATES = [
    [ "Maharashtra", "Maharashtra GST Department", "https://www.mahagst.gov.in/en/profession-tax-and-other-rate-schedule" ],
    [ "Karnataka", "Karnataka Professional Tax", "https://ptax.karnataka.gov.in/" ],
    [ "Telangana", "Telangana Commercial Taxes", "https://www.tgct.gov.in/tgportal/PT_Dashboard/PT_Home.aspx" ],
    [ "Gujarat", "Gujarat Commercial Tax", "https://commercialtax.gujarat.gov.in/vatwebsite/schedules/schedulesMain.jsp?viewPageNo=6" ],
    [ "Tamil Nadu", "Tamil Nadu Urban ePay", "https://tnurbanepay.tn.gov.in/CP_ProfTaxPaymentDetails.aspx" ],
    [ "Andhra Pradesh", "AP Finance — Ease of Doing Business", "https://apfinance.gov.in/EODB.html" ],
    [ "West Bengal", "West Bengal Profession Tax", "https://professiontax.wb.gov.in/quick-pay/quickpay-landing/" ]
  ].freeze

  def index; end

  # Each calculator has its own page so it can carry its own title, heading and
  # explanatory content; /resources/payroll-calculators is the hub that lists
  # them. They share the same sources and review date.
  def calculators
    calculator_context
  end

  def pf_calculator
    calculator_context
  end

  def esi_calculator
    calculator_context
  end

  def ctc_calculator
    calculator_context
  end

  def compliance_calendar
    @official_sources = COMPLIANCE_SOURCES
    @last_reviewed = LAST_REVIEWED
  end

  def payroll_checklist
    @last_reviewed = LAST_REVIEWED
  end

  def professional_tax
    @states = PROFESSIONAL_TAX_STATES
    @last_reviewed = LAST_REVIEWED
  end

  private

  def calculator_context
    @official_sources = OFFICIAL_SOURCES
    @last_reviewed = LAST_REVIEWED
  end
end
