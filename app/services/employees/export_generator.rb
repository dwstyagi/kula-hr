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
      file = self.file
      File.binread(file.path)
    ensure
      file&.close!
    end

    def file
      file = Tempfile.new([ "employees", ".xlsx" ])
      file.close
      Zip::OutputStream.open(file.path) do |zip|
        parts = {
          "[Content_Types].xml" => '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
          "_rels/.rels" => '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
          "xl/workbook.xml" => '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Employees" sheetId="1" r:id="rId1"/></sheets></workbook>',
          "xl/_rels/workbook.xml.rels" => '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>'
        }
        parts.each { |name, xml| zip.put_next_entry(name); zip.write(xml) }
        zip.put_next_entry("xl/worksheets/sheet1.xml")
        zip.write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>')
        write_row(zip, COLUMNS.map { |c| c[:header] }, 1)
        index = 1
        source = @employees.respond_to?(:find_each) ? @employees.reorder(:id).find_each(batch_size: 100) : @employees.each
        source.each do |employee|
          values = COLUMNS.map do |column|
            raw = column[:key].is_a?(Proc) ? column[:key].call(employee) : employee.public_send(column[:key])
            raw.is_a?(Date) ? raw.strftime("%d/%m/%Y") : raw.to_s
          end
          write_row(zip, values, index += 1)
        end
        zip.write("</sheetData></worksheet>")
      end
      file
    rescue Exception
      file&.close!
      raise
    end

    private

    def write_row(zip, values, index)
      zip.write(%(<row r="#{index}">))
      values.each_with_index do |value, column|
        letter = (65 + column).chr
        clean = value.to_s.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, "")
        zip.write(%(<c r="#{letter}#{index}" t="inlineStr"><is><t xml:space="preserve">#{ERB::Util.html_escape(clean)}</t></is></c>))
      end
      zip.write("</row>")
    end
  end
end
