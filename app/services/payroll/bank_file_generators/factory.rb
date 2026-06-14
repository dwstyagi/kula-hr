module Payroll
  module BankFileGenerators
    # Resolves the correct bank file generator (Strategy) for a given bank key
    # and owns the per-format file metadata. Centralizing this keeps the
    # controller free of bank-specific knowledge — adding a bank is a one-file
    # change here.
    class Factory
      DEFAULT = "generic_csv".freeze

      REGISTRY = {
        "hdfc"        => Hdfc,
        "icici"       => Icici,
        "sbi"         => Sbi,
        "generic_csv" => GenericCsv
      }.freeze

      # File metadata per bank key: [ extension, mime_type ]
      CSV_META = [ "csv", "text/csv" ].freeze
      TXT_META = [ "txt", "text/plain" ].freeze

      class << self
        def for(bank, payroll_run:)
          klass_for(bank).new(payroll_run: payroll_run)
        end

        def file_meta(bank)
          normalize(bank) == "generic_csv" ? CSV_META : TXT_META
        end

        def supported_banks
          REGISTRY.keys
        end

        private

        def klass_for(bank)
          REGISTRY.fetch(normalize(bank), GenericCsv)
        end

        def normalize(bank)
          bank.presence || DEFAULT
        end
      end
    end
  end
end
