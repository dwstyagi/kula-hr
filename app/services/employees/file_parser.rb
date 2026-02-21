module Employees
  class FileParser
    ParseError = Class.new(StandardError)

    EXPECTED_HEADERS = Employees::TemplateGenerator::HEADERS.freeze

    Result = Struct.new(:rows, :errors, keyword_init: true) do
      def success?
        errors.empty?
      end
    end

    def initialize(file)
      @file = file
    end

    def call
      spreadsheet = open_spreadsheet
      headers     = parse_headers(spreadsheet)
      validate_headers!(headers)
      rows = parse_rows(spreadsheet, headers)
      Result.new(rows: rows, errors: [])
    rescue ParseError => e
      Result.new(rows: [], errors: [ e.message ])
    rescue => e
      Result.new(rows: [], errors: [ "Could not read file: #{e.message}" ])
    end

    private

    def open_spreadsheet
      path = @file.respond_to?(:path) ? @file.path : @file.to_s
      Roo::Spreadsheet.open(path, extension: :xlsx)
    rescue
      raise ParseError, "Invalid file. Please upload a valid .xlsx file."
    end

    def parse_headers(spreadsheet)
      spreadsheet.row(1).map { |h| h.to_s.strip.downcase.gsub(/\s+/, "_") }
    end

    def validate_headers!(headers)
      missing = EXPECTED_HEADERS - headers
      return if missing.empty?

      raise ParseError, "Missing columns: #{missing.join(', ')}. Please use the official template."
    end

    def parse_rows(spreadsheet, headers)
      rows = []

      (2..spreadsheet.last_row).each do |row_num|
        raw = spreadsheet.row(row_num)
        next if raw.all?(&:blank?)

        row_data = headers.each_with_index.with_object({}) do |(header, index), hash|
          hash[header] = raw[index].to_s.strip.presence
        end

        row_data["_row"] = row_num
        rows << row_data
      end

      rows
    end
  end
end
