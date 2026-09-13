module Employees
  class ImportPreview
    PAGE_SIZE = 10
    EXPIRY = 30.minutes

    def initialize(key)
      @key = key
    end

    def write(rows)
      rows.each_slice(PAGE_SIZE).with_index(1) { |page, index| Rails.cache.write("#{@key}:#{index}", page, expires_in: EXPIRY) }
      Rails.cache.write(@key, { "total" => rows.size, "valid" => rows.count { |row| row["_valid"] } }, expires_in: EXPIRY)
    end

    def metadata = @key.present? ? Rails.cache.read(@key) : nil
    def page(number) = Rails.cache.read("#{@key}:#{number}")

    def all_rows
      info = metadata
      return unless info
      pages = (1..(info["total"].to_f / PAGE_SIZE).ceil).map { |number| page(number) }
      return if pages.any?(&:nil?)
      pages.flatten(1)
    end
  end
end
