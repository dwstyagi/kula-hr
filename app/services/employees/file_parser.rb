module Employees
  class FileParser
    ParseError = Class.new(StandardError)
    MAX_ROWS = 1_000
    MAX_FILE_BYTES = 10.megabytes
    MAX_EXPANDED_BYTES = 25.megabytes
    MAX_CELL_LENGTH = 2_000

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
      rows = []
      headers = nil
      spreadsheet.each_row_streaming(pad_cells: false) do |cells|
        raise ParseError, "Too many columns. Use the official template." if cells.size > EXPECTED_HEADERS.size
        raw = []
        cells.each do |cell|
          column = cell.coordinate.column
          raise ParseError, "Too many columns. Use the official template." unless (1..EXPECTED_HEADERS.size).cover?(column)
          raw[column - 1] = cell.value
        end
        if headers.nil?
          headers = raw.map { |h| h.to_s.strip.downcase.gsub(/\s+/, "_") }
          validate_headers!(headers)
          next
        end
        raise ParseError, "Upload at most #{MAX_ROWS} employees per file." if rows.size >= MAX_ROWS
        next if raw.all?(&:blank?)
        values = headers.each_with_index.to_h do |header, index|
          value = raw[index]
          raise ParseError, "Cell exceeds #{MAX_CELL_LENGTH} characters." if value.to_s.length > MAX_CELL_LENGTH
          [ header, value.is_a?(Date) ? value.strftime("%d/%m/%Y") : value.to_s.strip.presence ]
        end
        rows << values.merge("_row" => rows.size + 1)
      end
      raise ParseError, "Spreadsheet is empty." unless headers
      Result.new(rows: rows, errors: [])
    rescue ParseError => e
      Result.new(rows: [], errors: [ e.message ])
    rescue => e
      Result.new(rows: [], errors: [ "Could not read file: #{e.message}" ])
    end

    private

    def open_spreadsheet
      path = @file.respond_to?(:path) ? @file.path : @file.to_s
      raise ParseError, "File must be smaller than 10 MB." if File.size(path) > MAX_FILE_BYTES
      Zip::File.open(path) do |zip|
        raise ParseError, "Spreadsheet is too large when expanded." if zip.entries.sum(&:size) > MAX_EXPANDED_BYTES
        raise ParseError, "Spreadsheet has too many parts." if zip.entries.size > 100
        zip.entries.each do |entry|
          next unless entry.name.match?(%r{\Axl/(worksheets/.*|sharedStrings)\.xml\z})
          rows = cells = strings = 0
          entry.get_input_stream do |io|
            Nokogiri::XML::Reader(io).each do |node|
              next unless node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
              case node.name
              when "row"
                rows += 1
                cells = 0
                raise ParseError, "Upload at most #{MAX_ROWS} employees per file." if rows > MAX_ROWS + 1
              when "c"
                cells += 1
                column = node.attribute("r").to_s[/\A[A-Z]+/].to_s.each_byte.reduce(0) { |n, c| n * 26 + c - 64 }
                raise ParseError, "Too many columns. Use the official template." if cells > EXPECTED_HEADERS.size || column > EXPECTED_HEADERS.size
              when "si"
                strings += 1
                raise ParseError, "Too many spreadsheet strings." if strings > (MAX_ROWS + 1) * EXPECTED_HEADERS.size
              end
            end
          end
        end
      end
      Roo::Spreadsheet.open(path, extension: :xlsx)
    rescue ParseError
      raise
    rescue
      raise ParseError, "Invalid file. Please upload a valid .xlsx file."
    end

    def validate_headers!(headers)
      missing = EXPECTED_HEADERS - headers
      return if missing.empty?

      raise ParseError, "Missing columns: #{missing.join(', ')}. Please use the official template."
    end
  end
end
