module Employees
  class ErrorReportGenerator
    # Columns to include in the error report (same as template, minus internal keys)
    COLUMNS = Employees::TemplateGenerator::HEADERS

    def initialize(invalid_rows)
      @invalid_rows = invalid_rows
    end

    # Returns raw xlsx binary data
    def call
      package = Axlsx::Package.new
      workbook = package.workbook

      # Styles
      workbook.styles do |s|
        header_style = s.add_style(
          bg_color:  "2563EB",
          fg_color:  "FFFFFF",
          b:         true,
          sz:        11,
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          border:    { style: :thin, color: "BFDBFE" }
        )

        remarks_header_style = s.add_style(
          bg_color:  "DC2626",
          fg_color:  "FFFFFF",
          b:         true,
          sz:        11,
          alignment: { horizontal: :center, vertical: :center, wrap_text: true },
          border:    { style: :thin, color: "FCA5A5" }
        )

        data_style = s.add_style(
          sz:        10,
          alignment: { vertical: :center, wrap_text: true },
          border:    { style: :thin, color: "E5E7EB" }
        )

        remarks_style = s.add_style(
          fg_color:  "991B1B",
          bg_color:  "FEF2F2",
          sz:        10,
          alignment: { vertical: :center, wrap_text: true },
          border:    { style: :thin, color: "FECACA" }
        )

        workbook.add_worksheet(name: "Import Errors") do |sheet|
          # Header row — all data columns + Remarks
          headers       = COLUMNS.map { |h| h.humanize }
          header_styles = Array.new(COLUMNS.size, header_style) + [ remarks_header_style ]
          sheet.add_row headers + [ "Remarks" ], style: header_styles, height: 24

          # Data rows
          @invalid_rows.each do |row|
            values = COLUMNS.map { |col| row[col].presence || "" }
            remarks = row["_errors"]&.join("; ") || ""
            row_styles = Array.new(COLUMNS.size, data_style) + [ remarks_style ]
            sheet.add_row values + [ remarks ], style: row_styles, height: 20
          end

          # Set column widths
          col_widths = COLUMNS.map { 18 } + [ 60 ]
          sheet.column_widths(*col_widths)

          # Freeze header row
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
