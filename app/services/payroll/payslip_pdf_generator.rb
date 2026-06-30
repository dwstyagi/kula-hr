# Renders the "Stamped Treasury Record" payslip — an IBM Plex / treasury-teal
# document with an official seal. Fonts are embedded from app/assets/fonts so the
# ₹ glyph renders and the type carries personality (Prawn's built-in AFM fonts
# have neither). The seal is a pre-rendered asset (app/assets/images/payslip_seal.png).
class Payroll::PayslipPdfGenerator
  FONT_DIR  = Rails.root.join("app/assets/fonts")
  SEAL_PATH = Rails.root.join("app/assets/images/payslip_seal.png")

  # Palette (mirrors the approved HTML mockup)
  INK         = "1B2421"
  TEAL        = "0C4A45"
  TEAL_SOFT   = "13635A"
  MUTED       = "737C76"
  FAINT       = "9AA39D"
  HAIR        = "DBDED8"
  HAIR_STRONG = "C3C8C0"
  TINT        = "F3F4F0"
  TINT_TEAL   = "EEF3F1"
  WHITE       = "FFFFFF"

  def initialize(payslip:)
    @payslip  = payslip
    @employee = payslip.employee
    @tenant   = payslip.tenant
  end

  def call
    Prawn::Fonts::AFM.hide_m17n_warning = true
    pdf = Prawn::Document.new(page_size: "A4", margin: 0)
    register_fonts(pdf)
    pdf.font "PlexSans"

    draw_frame(pdf)

    pdf.bounding_box([ 44, pdf.bounds.height - 46 ], width: pdf.bounds.width - 88) do
      render_masthead(pdf)
      rule(pdf, HAIR_STRONG, 18)
      render_details(pdf)
      rule(pdf, HAIR, 16)
      render_attendance(pdf)
      render_ledger(pdf)
      render_net_pay(pdf)
      render_trio(pdf)
      render_footer(pdf)
    end

    pdf.render
  end

  private

  # ── Fonts ────────────────────────────────────────────────────────────────────
  def register_fonts(pdf)
    pdf.font_families.update(
      "PlexSans" => {
        normal: FONT_DIR.join("IBMPlexSans-Regular.ttf").to_s,
        bold:   FONT_DIR.join("IBMPlexSans-SemiBold.ttf").to_s
      },
      "PlexSansMed" => {
        normal: FONT_DIR.join("IBMPlexSans-Medium.ttf").to_s,
        bold:   FONT_DIR.join("IBMPlexSans-SemiBold.ttf").to_s
      },
      "PlexCond" => {
        normal: FONT_DIR.join("IBMPlexSansCondensed-SemiBold.ttf").to_s,
        bold:   FONT_DIR.join("IBMPlexSansCondensed-Bold.ttf").to_s
      },
      "PlexMono" => {
        normal: FONT_DIR.join("IBMPlexMono-Regular.ttf").to_s,
        bold:   FONT_DIR.join("IBMPlexMono-SemiBold.ttf").to_s
      },
      "PlexMonoMed" => {
        normal: FONT_DIR.join("IBMPlexMono-Medium.ttf").to_s,
        bold:   FONT_DIR.join("IBMPlexMono-SemiBold.ttf").to_s
      }
    )
  end

  # ── Security double-hairline frame ───────────────────────────────────────────
  def draw_frame(pdf)
    pdf.stroke_color HAIR_STRONG
    pdf.line_width 1
    pdf.stroke_rectangle [ 18, pdf.bounds.height - 18 ], pdf.bounds.width - 36, pdf.bounds.height - 36
    pdf.stroke_color HAIR
    pdf.line_width 0.5
    pdf.stroke_rectangle [ 25, pdf.bounds.height - 25 ], pdf.bounds.width - 50, pdf.bounds.height - 50
    pdf.line_width 1
    pdf.stroke_color "000000"
  end

  # ── Masthead ─────────────────────────────────────────────────────────────────
  def render_masthead(pdf)
    top = pdf.cursor
    pdf.stroke_color TEAL
    pdf.line_width 1.5
    pdf.stroke_rounded_rectangle [ 0, top ], 40, 40, 3
    pdf.line_width 1
    pdf.fill_color TEAL
    pdf.font("PlexCond", style: :bold) do
      pdf.text_box @tenant.name[0, 1].upcase, at: [ 0, top - 9 ], width: 40, align: :center, size: 22
    end

    pdf.fill_color INK
    pdf.font("PlexCond", style: :bold) do
      pdf.text_box @tenant.name.upcase, at: [ 52, top - 1 ], width: 320, size: 20
    end
    pdf.fill_color MUTED
    pdf.font("PlexSans") do
      pdf.text_box company_address, at: [ 52, top - 24 ], width: 320, size: 9.5
    end
    ids = company_ids
    unless ids.empty?
      pdf.fill_color MUTED
      pdf.font("PlexMono") { pdf.text_box ids, at: [ 52, top - 38 ], width: 320, size: 8.5 }
    end

    pdf.fill_color TEAL
    pdf.font("PlexCond", style: :bold) do
      pdf.text_box "SALARY SLIP", at: [ pdf.bounds.width - 220, top - 1 ], width: 220, align: :right, size: 14, character_spacing: 1.5
    end
    pdf.fill_color INK
    pdf.font("PlexSans", style: :bold) do
      pdf.text_box "#{@payslip.month_name} #{@payslip.year}", at: [ pdf.bounds.width - 220, top - 18 ], width: 220, align: :right, size: 12.5
    end
    pdf.fill_color MUTED
    pdf.font("PlexMono") do
      pdf.text_box "No. #{slip_no}", at: [ pdf.bounds.width - 280, top - 34 ], width: 280, align: :right, size: 8
    end

    pdf.fill_color "000000"
    pdf.move_cursor_to top - 50
  end

  # ── Employee + Pay Period grids ──────────────────────────────────────────────
  def render_details(pdf)
    top   = pdf.cursor
    col_w = (pdf.bounds.width - 30) / 2.0

    employee_rows = [
      [ "Name",            @employee.full_name,                   :sans ],
      [ "Emp ID",          @employee.employee_code,               :mono ],
      [ "Designation",     @employee.designation&.name || "—",    :sans ],
      [ "Department",      @employee.department&.name || "—",     :sans ],
      [ "Date of Joining", fmt_date(@employee.joining_date),      :mono ],
      [ "PAN",             @employee.pan_number.presence || "—",  :mono ],
      [ "UAN",             @employee.uan_number.presence || "—",  :mono ]
    ]
    period_rows = [
      [ "Month",    "#{@payslip.month_name} #{@payslip.year}",     :sans ],
      [ "Period",   period_range,                                  :mono ],
      [ "Pay Date", pay_date,                                      :mono ],
      [ "Mode",     "Bank Transfer",                               :sans ],
      [ "Bank",     @employee.bank_name.presence || "—",           :sans ],
      [ "Account",  mask_account(@employee.bank_account_number),   :mono ],
      [ "IFSC",     @employee.ifsc_code.presence || "—",           :mono ]
    ]

    eyebrow(pdf, "Employee", 0, top)
    eyebrow(pdf, "Pay Period", col_w + 30, top)
    detail_list(pdf, employee_rows, 0,          top - 16, col_w)
    detail_list(pdf, period_rows,   col_w + 30, top - 16, col_w)

    pdf.move_cursor_to top - 16 - employee_rows.size * 17 - 2
  end

  def detail_list(pdf, rows, x, y, width)
    rows.each_with_index do |(label, value, kind), i|
      ry = y - i * 17
      pdf.fill_color FAINT
      pdf.font("PlexCond", style: :bold) do
        pdf.text_box label.upcase, at: [ x, ry ], width: 86, size: 8, character_spacing: 0.3
      end
      pdf.fill_color INK
      font = kind == :mono ? "PlexMono" : "PlexSansMed"
      pdf.font(font) do
        pdf.text_box value.to_s, at: [ x + 92, ry ], width: width - 92, size: kind == :mono ? 10.5 : 11
      end
    end
    pdf.fill_color "000000"
  end

  # ── Attendance strip ─────────────────────────────────────────────────────────
  def render_attendance(pdf)
    eyebrow(pdf, "Attendance", 0, pdf.cursor)
    pdf.move_down 14
    top = pdf.cursor
    w   = pdf.bounds.width
    h   = 40

    pdf.fill_color TINT
    pdf.fill_rounded_rectangle [ 0, top ], w, h, 4
    pdf.stroke_color HAIR
    pdf.line_width 0.5
    pdf.stroke_rounded_rectangle [ 0, top ], w, h, 4

    cells = [
      [ "Working Days", num(@payslip.total_working_days), false ],
      [ "Paid Days",    num(@payslip.paid_days),          false ],
      [ "Loss of Pay",  num(@payslip.lop_days),           true  ],
      [ "Proration",    format("%.3f", proration),        false ]
    ]
    cw = w / cells.size.to_f
    cells.each_with_index do |(k, v, accent), i|
      x = i * cw
      unless i.zero?
        pdf.stroke_color HAIR
        pdf.stroke_line [ x, top ], [ x, top - h ]
      end
      pdf.fill_color MUTED
      pdf.font("PlexCond", style: :bold) { pdf.text_box k.upcase, at: [ x + 13, top - 9 ], width: cw - 16, size: 8 }
      pdf.fill_color(accent ? TEAL : INK)
      pdf.font("PlexMonoMed") { pdf.text_box v, at: [ x + 13, top - 21 ], width: cw - 16, size: 15 }
    end

    pdf.fill_color MUTED
    pdf.font("PlexSans") do
      pdf.text_box "Earnings prorated for #{num(@payslip.paid_days)} of #{num(@payslip.total_working_days)} paid days (#{num(@payslip.lop_days)} LOP days).",
        at: [ 0, top - h - 8 ], width: w, size: 9.5
    end
    pdf.fill_color "000000"
    pdf.move_cursor_to top - h - 24
  end

  # ── Earnings / Deductions ledger ─────────────────────────────────────────────
  def render_ledger(pdf)
    pdf.move_down 6
    earnings   = @payslip.earnings.to_a
    deductions = @payslip.deductions.to_a
    max_rows   = [ earnings.size, deductions.size ].max

    body = max_rows.times.map do |i|
      e = earnings[i]; d = deductions[i]
      [
        e ? e.component_name : "", e ? num(e.amount) : "",
        d ? d.component_name : "", d ? num(d.amount) : ""
      ]
    end
    head = [ [ "EARNINGS", "₹", "DEDUCTIONS", "₹" ] ]
    tot  = [ [ "Gross Earnings", num(@payslip.gross_pay), "Total Deductions", num(@payslip.total_deductions) ] ]

    amt_w  = 96.0
    name_w = (pdf.bounds.width - amt_w * 2) / 2.0

    ledger_top = pdf.cursor
    pdf.table(head + body + tot, width: pdf.bounds.width,
              column_widths: [ name_w, amt_w, name_w, amt_w ]) do |t|
      t.cells.borders = []
      t.cells.padding = [ 7, 12, 7, 12 ]

      t.row(0).background_color = INK
      t.row(0).text_color = WHITE
      t.row(0).font = "PlexCond"
      t.row(0).font_style = :bold
      t.row(0).size = 10.5
      t.row(0).column(1).text_color = "9FB0AB"
      t.row(0).column(3).text_color = "9FB0AB"

      t.rows(1..max_rows).size = 10.5
      t.rows(1..max_rows).text_color = INK
      t.rows(1..max_rows).borders = [ :bottom ]
      t.rows(1..max_rows).border_color = HAIR
      t.rows(1..max_rows).border_width = 0.5

      t.row(-1).background_color = TINT_TEAL
      t.row(-1).text_color = TEAL
      t.row(-1).font = "PlexCond"
      t.row(-1).font_style = :bold
      t.row(-1).size = 10.5

      [ 1, 3 ].each do |c|
        t.column(c).align = :right
        t.rows(1..-1).column(c).font = "PlexMonoMed"
        # never let an amount wrap to a second line — shrink as a last resort
        t.column(c).overflow = :shrink_to_fit
        t.column(c).min_font_size = 7
      end
    end
    ledger_bottom = pdf.cursor

    # vertical divider between the two ledgers + outer border
    mid = name_w + amt_w
    pdf.stroke_color HAIR_STRONG
    pdf.line_width 0.75
    pdf.stroke_line [ mid, ledger_top ], [ mid, ledger_bottom ]
    pdf.stroke_rectangle [ 0, ledger_top ], pdf.bounds.width, ledger_top - ledger_bottom
    pdf.stroke_color "000000"
    pdf.line_width 1
  end

  # ── Net pay + seal ───────────────────────────────────────────────────────────
  def render_net_pay(pdf)
    pdf.move_down 16
    top = pdf.cursor
    w   = pdf.bounds.width
    h   = 64
    net = @payslip.net_pay.round(0).to_i

    pdf.stroke_color TEAL
    pdf.line_width 1.5
    pdf.stroke_rounded_rectangle [ 0, top ], w, h, 5
    pdf.line_width 1

    pdf.fill_color TEAL_SOFT
    pdf.font("PlexCond", style: :bold) { pdf.text_box "NET PAY", at: [ 20, top - 14 ], width: 200, size: 11, character_spacing: 1.6 }
    pdf.fill_color MUTED
    pdf.font("PlexSans") { pdf.text_box "Rupees #{amount_in_words(net)} Only", at: [ 20, top - 32 ], width: 320, size: 10, leading: 1 }

    pdf.font("PlexMono", style: :bold) do
      pdf.formatted_text_box(
        [ { text: "₹", color: TEAL, size: 26 }, { text: indian(net), color: INK, size: 32 } ],
        at: [ w - 250, top - 16 ], width: 250, align: :right
      )
    end

    seal_w = 82
    sx = w - 246
    sy = top - (h - seal_w) / 2.0 + 4
    pdf.rotate(-8, origin: [ sx + seal_w / 2.0, sy - seal_w / 2.0 ]) do
      pdf.image SEAL_PATH.to_s, at: [ sx, sy ], width: seal_w
    end

    pdf.fill_color "000000"
    pdf.move_cursor_to top - h - 18
  end

  # ── Employer contribution + YTD ──────────────────────────────────────────────
  def render_trio(pdf)
    top   = pdf.cursor
    col_w = (pdf.bounds.width - 30) / 2.0

    in_ctc = setting&.employer_pf_in_ctc?
    hide   = setting&.hide_employer_contributions_on_slip?

    if hide
      # Company convention: hide employer PF; show the carved gross as "CTC".
      mini_header(pdf, "Cost to Company", "", 0, top, col_w)
      emp_rows = cost_to_company_rows(in_ctc)
    else
      mini_header(pdf, "Employer Contribution", in_ctc ? "· included in CTC" : "· not deducted", 0, top, col_w)
      emp_rows = [ [ "Employer PF (EPF + EPS)", num(@payslip.employer_pf) ] ]
      emp_rows << [ "PF Admin Charges", num(@payslip.employer_pf_admin) ] if @payslip.employer_pf_admin.to_f.positive?
      emp_rows << [ "EDLI Insurance",   num(@payslip.employer_edli) ]     if @payslip.employer_edli.to_f.positive?
      emp_rows << [ "Employer ESI",     num(@payslip.employer_esi) ]      if @payslip.employer_esi.to_f.positive?
      emp_rows << [ "CTC This Month",   num(@payslip.ctc_this_month) ]
    end

    mini_header(pdf, "Year to Date", "· FY #{fy_label}", col_w + 30, top, col_w)
    y = ytd
    ytd_rows = [
      [ "Gross Earnings",   num(y[:gross]) ],
      [ "EPF",              num(y[:pf]) ],
      [ "Income Tax (TDS)", num(y[:tds]) ],
      [ "Net Paid",         num(y[:net]) ]
    ]

    mini_rows(pdf, emp_rows, 0,          top - 26, col_w)
    mini_rows(pdf, ytd_rows, col_w + 30, top - 26, col_w)

    rows = [ emp_rows.size, ytd_rows.size ].max
    pdf.move_cursor_to top - 26 - rows * 16 - 6
  end

  def mini_header(pdf, title, sub, x, y, width)
    pdf.fill_color MUTED
    tw = 0
    pdf.font("PlexCond", style: :bold) do
      pdf.text_box title.upcase, at: [ x, y ], width: width, size: 10, character_spacing: 0.6
      tw = pdf.width_of(title.upcase, size: 10) + (title.length * 0.6) + 8
    end
    pdf.fill_color FAINT
    pdf.font("PlexSans") { pdf.text_box sub, at: [ x + tw, y - 0.5 ], width: width - tw, size: 9 }
    pdf.stroke_color HAIR
    pdf.line_width 0.5
    pdf.stroke_line [ x, y - 12 ], [ x + width, y - 12 ]
    pdf.line_width 1
    pdf.fill_color "000000"
  end

  def mini_rows(pdf, rows, x, y, width)
    amt_w = 96
    rows.each_with_index do |(label, amount), i|
      ry = y - i * 16
      pdf.fill_color MUTED
      pdf.font("PlexSans") { pdf.text_box label, at: [ x, ry ], width: width - amt_w - 6, size: 11, overflow: :truncate }
      pdf.fill_color INK
      pdf.font("PlexMonoMed") { pdf.text_box amount, at: [ x + width - amt_w, ry ], width: amt_w, align: :right, size: 11, single_line: true }
    end
    pdf.fill_color "000000"
  end

  # ── Footer ───────────────────────────────────────────────────────────────────
  def render_footer(pdf)
    pdf.move_down 14
    rule(pdf, HAIR, 8)
    pdf.fill_color FAINT
    pdf.font("PlexSans") do
      pdf.text_box "This is a computer-generated salary slip and does not require a signature.",
        at: [ 0, pdf.cursor ], width: pdf.bounds.width, align: :center, size: 9
      contact = @tenant.try(:email).presence
      if contact
        pdf.text_box "For payroll queries, contact #{contact}",
          at: [ 0, pdf.cursor - 12 ], width: pdf.bounds.width, align: :center, size: 9
      end
    end
    pdf.fill_color "000000"
  end

  # ── Shared bits ──────────────────────────────────────────────────────────────
  def eyebrow(pdf, text, x, y)
    pdf.fill_color MUTED
    pdf.font("PlexCond", style: :bold) { pdf.text_box text.upcase, at: [ x, y ], width: 200, size: 9.5, character_spacing: 1.2 }
    pdf.fill_color "000000"
  end

  def rule(pdf, color, gap)
    pdf.move_down gap
    pdf.stroke_color color
    pdf.line_width(color == HAIR_STRONG ? 1 : 0.5)
    pdf.stroke_horizontal_rule
    pdf.line_width 1
    pdf.stroke_color "000000"
    pdf.move_down gap
  end

  # ── Data helpers ─────────────────────────────────────────────────────────────
  def company_address
    [ @tenant.try(:address), @tenant.try(:city), @tenant.try(:state), @tenant.try(:pincode) ]
      .map { |v| v.to_s.strip }.reject(&:empty?).join(", ").presence || " "
  end

  def company_ids
    parts = []
    parts << "PAN  #{@tenant.pan}" if @tenant.try(:pan).present?
    parts << "TAN  #{@tenant.tan}" if @tenant.try(:tan).present?
    parts.join("     ")
  end

  def proration
    wd = @payslip.total_working_days.to_f
    wd.zero? ? 1.0 : (@payslip.paid_days.to_f / wd)
  end

  def setting
    @setting ||= @tenant.payroll_setting
  end

  # "Show Y as CTC": annual CTC net of the employer PF that's been carved in.
  def cost_to_company_rows(in_ctc)
    salary = @employee.current_salary
    return [] unless salary

    annual_employer = (@payslip.employer_pf + @payslip.employer_pf_admin + @payslip.employer_edli) * 12
    annual_ctc = salary.annual_ctc - (in_ctc ? annual_employer : 0)
    [ [ "Annual CTC", num(annual_ctc) ], [ "Monthly", num(annual_ctc / 12.0) ] ]
  end

  def fy_bounds
    @payslip.month >= 4 ? [ @payslip.year, @payslip.year + 1 ] : [ @payslip.year - 1, @payslip.year ]
  end

  def fy_label
    s, e = fy_bounds
    "#{s}-#{e.to_s[2, 2]}"
  end

  def ytd
    @ytd ||= begin
      start_year, = fy_bounds
      scope = Payslip.where(employee_id: @employee.id)
        .where("(year > ? OR (year = ? AND month >= 4))", start_year, start_year)
        .where("(year < ? OR (year = ? AND month <= ?))", @payslip.year, @payslip.year, @payslip.month)
      ids = scope.pluck(:id)
      pf  = PayslipLineItem.where(payslip_id: ids, component_name: [ "PF", "EPF", "Provident Fund" ]).sum(:amount)
      tds = PayslipLineItem.where(payslip_id: ids, component_name: [ "TDS", "Income Tax (TDS)", "Income Tax" ]).sum(:amount)
      { gross: scope.sum(:gross_pay), net: scope.sum(:net_pay), pf: pf, tds: tds }
    end
  end

  def slip_no
    prefix = @tenant.name.upcase.gsub(/[^A-Z]/, "")[0, 4].presence || "PSLP"
    "#{prefix}/#{fy_label}/#{format('%02d', @payslip.month)}/#{@employee.employee_code}"
  end

  def pay_date
    d = @payslip.payroll_run&.approved_at&.to_date || Date.new(@payslip.year, @payslip.month, 1).end_of_month
    d.strftime("%d %b %Y")
  end

  def period_range
    s = Date.new(@payslip.year, @payslip.month, 1)
    "#{s.strftime('%d %b')} – #{s.end_of_month.strftime('%d %b %Y')}"
  end

  def fmt_date(d)
    d ? d.strftime("%d %b %Y") : "—"
  end

  def mask_account(number)
    return "—" if number.blank?
    "X" * [ number.length - 4, 0 ].max + number.to_s.last(4)
  end

  # Indian digit grouping: 1234567 -> 12,34,567
  def indian(n)
    s = n.to_i.abs.to_s
    return s if s.length <= 3
    last3 = s[-3..]
    rest  = s[0...-3].reverse.scan(/\d{1,2}/).join(",").reverse
    "#{rest},#{last3}"
  end

  def num(amount)
    indian(amount.to_f.round(0).to_i)
  end

  def amount_in_words(amount)
    return "Zero Rupees" if amount.zero?
    ones = %w[Zero One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve
              Thirteen Fourteen Fifteen Sixteen Seventeen Eighteen Nineteen]
    tens = %w[Zero Ten Twenty Thirty Forty Fifty Sixty Seventy Eighty Ninety]
    seg = lambda do |n|
      next "" if n.zero?
      next ones[n] if n < 20
      next tens[n / 10] + (n % 10 > 0 ? " #{ones[n % 10]}" : "") if n < 100
      "#{ones[n / 100]} Hundred#{n % 100 > 0 ? ' ' + seg.call(n % 100) : ''}"
    end
    crore = amount / 10_000_000
    lakh  = (amount % 10_000_000) / 100_000
    thous = (amount % 100_000) / 1_000
    rest  = amount % 1_000
    parts = []
    parts << "#{seg.call(crore)} Crore"    if crore > 0
    parts << "#{seg.call(lakh)} Lakh"      if lakh > 0
    parts << "#{seg.call(thous)} Thousand" if thous > 0
    parts << seg.call(rest)                if rest > 0
    parts.join(" ").strip
  end
end
