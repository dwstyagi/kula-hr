module Employees
  class ExportGenerator
    COLUMNS = [
      { header: "Employee Code",   key: :employee_code },
      { header: "First Name",      key: :first_name },
      { header: "Last Name",       key: :last_name },
      { header: "Email",           key: :email },
      { header: "Phone",           key: :phone },
      { header: "Date of Birth",   key: :date_of_birth },
      { header: "Gender",          key: :gender },
      { header: "Joining Date",    key: :joining_date },
      { header: "Status",          key: :employment_status },
      { header: "Department",      key: ->(e) { e.department&.name } },
      { header: "Designation",     key: ->(e) { e.designation&.name } },
      { header: "PAN",             key: :pan_number },
      { header: "Aadhaar",         key: :aadhaar_number },
      { header: "UAN",             key: :uan_number },
      { header: "ESI",             key: :esi_number },
      { header: "Bank Name",       key: :bank_name },
      { header: "Account Number",  key: :bank_account_number },
      { header: "IFSC Code",       key: :ifsc_code },
      { header: "Address",         key: :current_address },
      { header: "City",            key: :city },
      { header: "State",           key: :state },
      { header: "Pincode",         key: :pincode },
      { header: "Emergency Name",  key: :emergency_contact_name },
      { header: "Emergency Phone", key: :emergency_contact_phone },
      { header: "Emergency Relation", key: :emergency_contact_relation }
    ].freeze

    def initialize(employees)
      @employees = employees
    end

    def call
      package  = Axlsx::Package.new
      workbook = package.workbook

      workbook.styles do |s|
        header_style = s.add_style(
          bg_color:  "1D4ED8",
          fg_color:  "FFFFFF",
          b:         true,
          sz:        11,
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          border:    { style: :thin, color: "3B82F6" }
        )

        even_row = s.add_style(
          bg_color:  "F8FAFC",
          sz:        10,
          alignment: { vertical: :center },
          border:    { style: :thin, color: "E2E8F0" }
        )

        odd_row = s.add_style(
          bg_color:  "FFFFFF",
          sz:        10,
          alignment: { vertical: :center },
          border:    { style: :thin, color: "E2E8F0" }
        )

        workbook.add_worksheet(name: "Employees") do |sheet|
          # Header row
          sheet.add_row COLUMNS.map { |c| c[:header] },
                        style: Array.new(COLUMNS.size, header_style),
                        height: 24

          # Data rows
          @employees.each_with_index do |emp, idx|
            values = COLUMNS.map do |col|
              raw = col[:key].is_a?(Proc) ? col[:key].call(emp) : emp.public_send(col[:key])
              raw.is_a?(Date) ? raw.strftime("%d/%m/%Y") : raw.to_s.presence || ""
            end

            row_style = Array.new(COLUMNS.size, idx.even? ? even_row : odd_row)
            sheet.add_row values, style: row_style, height: 18
          end

          # Column widths
          sheet.column_widths(*Array.new(COLUMNS.size, 20))

          # Freeze header
          sheet.sheet_view.pane do |pane|
            pane.top_left_cell = "A2"
            pane.state         = :frozen_split
            pane.y_split       = 1
            pane.active_pane   = :bottom_left
          end
        end
      end

      package.to_stream.read
    end
  end
end
