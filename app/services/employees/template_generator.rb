module Employees
  class TemplateGenerator
    HEADERS = [
      "first_name",
      "last_name",
      "email",
      "phone",
      "date_of_birth",
      "gender",
      "joining_date",
      "employment_status",
      "department",
      "designation",
      "pan_number",
      "aadhaar_number",
      "uan_number",
      "esi_number",
      "bank_name",
      "bank_account_number",
      "ifsc_code",
      "current_address",
      "city",
      "state",
      "pincode",
      "emergency_contact_name",
      "emergency_contact_phone",
      "emergency_contact_relation"
    ].freeze

    SAMPLE_ROW = [
      "John",
      "Doe",
      "john.doe@example.com",
      "9876543210",
      "15/08/1990",
      "male",
      "01/02/2026",
      "active",
      "Engineering",
      "Software Engineer",
      "ABCDE1234F",
      "123456789012",
      "100123456789",
      "",
      "HDFC Bank",
      "12345678901234",
      "HDFC0001234",
      "123 MG Road",
      "Bengaluru",
      "Karnataka",
      "560001",
      "Jane Doe",
      "9876543211",
      "Spouse"
    ].freeze

    NOTES_ROW = [
      "Required",
      "Required",
      "Required — must be unique",
      "Optional",
      "Required — DD/MM/YYYY",
      "Optional — male / female / other",
      "Required — DD/MM/YYYY",
      "Required — active / probation / notice_period / resigned / terminated",
      "Optional — must match existing department name",
      "Optional — must match existing designation name",
      "Optional — format: ABCDE1234F",
      "Optional — 12 digits",
      "Optional — UAN number",
      "Optional — ESI number",
      "Optional",
      "Optional",
      "Optional — format: HDFC0001234",
      "Optional",
      "Optional",
      "Optional",
      "Optional — 6 digits",
      "Optional",
      "Optional",
      "Optional"
    ].freeze

    def call
      package = Axlsx::Package.new

      package.workbook.add_worksheet(name: "Employees") do |sheet|
        # Header style — bold, white text, blue background
        header_style = sheet.styles.add_style(
          bg_color: "2563EB",
          fg_color: "FFFFFF",
          b: true,
          sz: 11,
          alignment: { horizontal: :center, wrap_text: true },
          border: { style: :thin, color: "1D4ED8" }
        )

        # Notes style — italic, gray
        notes_style = sheet.styles.add_style(
          fg_color: "6B7280",
          i: true,
          sz: 9,
          bg_color: "F9FAFB",
          alignment: { wrap_text: true }
        )

        # Sample row style — light blue tint
        sample_style = sheet.styles.add_style(
          bg_color: "EFF6FF",
          sz: 11,
          border: { style: :thin, color: "DBEAFE" }
        )

        # Row 1: Headers
        sheet.add_row HEADERS, style: header_style, height: 28

        # Row 2: Sample data
        sheet.add_row SAMPLE_ROW, style: sample_style, height: 20

        # Row 3: Notes/hints
        sheet.add_row NOTES_ROW, style: notes_style, height: 40

        # Set column widths
        sheet.column_widths 15, 15, 28, 14, 14, 10, 14, 16,
                            18, 20, 14, 16, 14, 12,
                            16, 20, 14, 25, 14, 14, 10,
                            20, 16, 12
      end

      package
    end
  end
end
