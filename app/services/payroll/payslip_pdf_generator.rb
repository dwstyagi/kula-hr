class Payroll::PayslipPdfGenerator
  DARK    = "1E293B"
  MID     = "475569"
  LIGHT   = "94A3B8"
  BORDER  = "E2E8F0"
  GREEN   = "059669"
  RED     = "DC2626"
  BG_GRAY = "F8FAFC"

  def initialize(payslip:)
    @payslip  = payslip
    @employee = payslip.employee
    @tenant   = payslip.tenant
  end

  def call
    Prawn::Fonts::AFM.hide_m17n_warning = true
    pdf = Prawn::Document.new(page_size: "A4", margin: [ 36, 40, 36, 40 ])

    render_header(pdf)
    render_divider(pdf)
    render_employee_details(pdf)
    render_attendance(pdf)
    render_divider(pdf)
    render_earnings_deductions(pdf)
    render_divider(pdf)
    render_net_pay(pdf)
    render_footer(pdf)

    pdf.render
  end

  private

  # ── Header ──────────────────────────────────────────────────────────────────

  def render_header(pdf)
    pdf.bounding_box([ 0, pdf.cursor ], width: pdf.bounds.width) do
      pdf.table(
        [[ company_info_cell(pdf), slip_title_cell(pdf) ]],
        width: pdf.bounds.width,
        cell_style: { borders: [], padding: 0 }
      )
    end
    pdf.move_down 14
  end

  def company_info_cell(pdf)
    {
      content: @tenant.name,
      font_style: :bold,
      size: 14,
      text_color: DARK,
      borders: [],
      padding: 0
    }.tap do |cell|
      # Build address string from available fields
      address_parts = [ @tenant.city, @tenant.state, @tenant.pincode ].compact.reject(&:empty?)
      unless address_parts.empty?
        cell[:content] = "#{@tenant.name}\n#{address_parts.join(', ')}"
      end
    end
  end

  def slip_title_cell(_pdf)
    {
      content: "SALARY SLIP\n#{@payslip.month_name} #{@payslip.year}",
      font_style: :bold,
      size: 13,
      text_color: DARK,
      align: :right,
      borders: [],
      padding: 0
    }
  end

  # ── Employee Details ─────────────────────────────────────────────────────────

  def render_employee_details(pdf)
    pdf.move_down 10

    data = [
      [ label("Employee"),     @employee.full_name,
        label("Employee Code"), @employee.employee_code ],
      [ label("Department"),   @employee.department&.name || "—",
        label("Designation"),  @employee.designation&.name || "—" ],
      [ label("PAN"),          @employee.pan_number.presence || "—",
        label("Bank A/C"),     mask_account(@employee.bank_account_number) ],
      [ label("UAN"),          @employee.uan_number.presence || "—",
        label("IFSC"),         @employee.ifsc_code.presence || "—" ]
    ]

    pdf.table(data,
      width:      pdf.bounds.width,
      cell_style: { borders: [], size: 9, padding: [ 3, 6, 3, 0 ], text_color: DARK }
    ) do |t|
      # Label columns (0 and 2) styled lighter
      [ 0, 2 ].each do |col|
        t.column(col).text_color = LIGHT
        t.column(col).width      = 90
      end
      t.column(1).width = pdf.bounds.width / 2 - 90
      t.column(3).width = pdf.bounds.width / 2 - 90
    end

    pdf.move_down 6
  end

  # ── Attendance ──────────────────────────────────────────────────────────────

  def render_attendance(pdf)
    parts = [
      "Working Days: #{@payslip.total_working_days}",
      "Paid Days: #{@payslip.paid_days}",
      "LOP Days: #{@payslip.lop_days}"
    ]
    pdf.fill_color BG_GRAY
    pdf.fill_rounded_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 22, 4
    pdf.fill_color "000000"

    pdf.bounding_box([ 8, pdf.cursor - 6 ], width: pdf.bounds.width - 16) do
      pdf.text parts.join("   |   "), size: 9, color: MID
    end
    pdf.move_down 16
  end

  # ── Earnings & Deductions ───────────────────────────────────────────────────

  def render_earnings_deductions(pdf)
    pdf.move_down 10

    earnings   = @payslip.earnings.to_a
    deductions = @payslip.deductions.to_a
    max_rows   = [ earnings.size, deductions.size ].max

    # Build row data
    rows = max_rows.times.map do |i|
      e = earnings[i]
      d = deductions[i]
      [
        e ? e.component_name : "",
        e ? fmt(e.amount)     : "",
        d ? d.component_name  : "",
        d ? fmt(d.amount)     : ""
      ]
    end

    # Totals row
    rows << [
      "Total Earnings",   fmt(@payslip.gross_pay),
      "Total Deductions", fmt(@payslip.total_deductions)
    ]

    amt_w  = 78.0
    name_w = (pdf.bounds.width - amt_w * 2) / 2.0

    pdf.table(
      [ [ "EARNINGS", "", "DEDUCTIONS", "" ] ] + rows,
      width:      pdf.bounds.width,
      column_widths: [ name_w, amt_w, name_w, amt_w ]
    ) do |t|
      # Header row
      t.row(0).background_color = DARK
      t.row(0).text_color       = "FFFFFF"
      t.row(0).font_style       = :bold
      t.row(0).size             = 9
      t.row(0).borders          = []

      # Body rows
      t.rows(1..-2).size       = 9
      t.rows(1..-2).text_color = DARK
      t.rows(1..-2).borders    = [ :bottom ]
      t.rows(1..-2).border_color = BORDER
      t.rows(1..-2).padding    = [ 5, 6 ]

      # Alternate row shading
      (1..(rows.size - 1)).each do |r|
        t.row(r).background_color = r.odd? ? "FFFFFF" : BG_GRAY if r < rows.size
      end

      # Amount columns right-aligned
      [ 1, 3 ].each { |c| t.column(c).align = :right }

      # Totals row (last)
      t.row(-1).font_style      = :bold
      t.row(-1).size            = 9
      t.row(-1).borders         = [ :top ]
      t.row(-1).border_color    = MID
      t.row(-1).background_color = "EFF6FF"
      t.row(-1).text_color      = DARK
      t.row(-1).padding         = [ 6, 6 ]
    end

    pdf.move_down 10
  end

  # ── Net Pay ─────────────────────────────────────────────────────────────────

  def render_net_pay(pdf)
    pdf.move_down 10

    net = @payslip.net_pay.round(0).to_i

    pdf.fill_color "EFF6FF"
    pdf.fill_rounded_rectangle [ 0, pdf.cursor ], pdf.bounds.width, 44, 6
    pdf.fill_color "000000"

    pdf.bounding_box([ 12, pdf.cursor - 10 ], width: pdf.bounds.width - 24) do
      pdf.text "NET PAY  #{fmt(net)}", size: 14, style: :bold, color: GREEN
      pdf.move_down 4
      pdf.text "(#{amount_in_words(net)} Only)", size: 8, color: MID
    end

    pdf.move_down 54

    # Employer costs row
    pdf.table(
      [ [
        "Employer PF: #{fmt(@payslip.employer_pf)}",
        "Employer ESI: #{fmt(@payslip.employer_esi)}",
        "CTC This Month: #{fmt(@payslip.ctc_this_month)}"
      ] ],
      width: pdf.bounds.width,
      cell_style: { borders: [], size: 8, text_color: LIGHT, padding: [ 2, 6, 2, 0 ] }
    )
  end

  # ── Footer ───────────────────────────────────────────────────────────────────

  def render_footer(pdf)
    pdf.move_down 20
    render_divider(pdf)
    pdf.move_down 6
    pdf.text "This is a computer-generated salary slip and does not require a signature.",
             size: 8, color: LIGHT, align: :center
    if @tenant.respond_to?(:email) && @tenant.email.present?
      pdf.text "For queries contact: #{@tenant.email}",
               size: 8, color: LIGHT, align: :center
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────────

  def render_divider(pdf)
    pdf.stroke_color BORDER
    pdf.stroke_horizontal_rule
    pdf.stroke_color "000000"
  end

  def label(text)
    { content: text, text_color: LIGHT, font_style: :normal }
  end

  def fmt(amount)
    "Rs.#{ActiveSupport::NumberHelper.number_to_delimited(amount.to_f.round(0).to_i)}"
  end

  def mask_account(number)
    return "—" if number.blank?
    "X" * [ number.length - 4, 0 ].max + number.last(4)
  end

  # Converts integer rupees to Indian-style words (up to crores)
  def amount_in_words(amount)
    return "Zero Rupees" if amount.zero?

    ones = %w[Zero One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve
              Thirteen Fourteen Fifteen Sixteen Seventeen Eighteen Nineteen]
    tens = %w[Zero Ten Twenty Thirty Forty Fifty Sixty Seventy Eighty Ninety]

    def to_words(n, ones, tens)
      return "" if n.zero?
      return ones[n] if n < 20
      return tens[n / 10] + (n % 10 > 0 ? " #{ones[n % 10]}" : "") if n < 100
      "#{ones[n / 100]} Hundred#{n % 100 > 0 ? ' ' + to_words(n % 100, ones, tens) : ''}"
    end

    crore = amount / 10_000_000
    lakh  = (amount % 10_000_000) / 100_000
    thous = (amount % 100_000) / 1_000
    rest  = amount % 1_000

    parts = []
    parts << "#{to_words(crore, ones, tens)} Crore"  if crore > 0
    parts << "#{to_words(lakh, ones, tens)} Lakh"    if lakh > 0
    parts << "#{to_words(thous, ones, tens)} Thousand" if thous > 0
    parts << to_words(rest, ones, tens)               if rest > 0

    "#{parts.join(' ')} Rupees"
  end
end
