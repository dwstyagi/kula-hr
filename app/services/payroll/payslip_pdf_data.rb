module Payroll
  class PayslipPdfData
    ASSOCIATIONS = [ :line_items, :payroll_run, :full_and_final_settlement,
      { tenant: :payroll_setting }, { employee: [ :department, :designation, :current_employee_salary ] } ].freeze

    def self.preload(payslips)
      ActiveRecord::Associations::Preloader.new(records: payslips, associations: ASSOCIATIONS).call
    end

    def self.ytd(employee_ids:, month:, year:)
      start_year = month >= 4 ? year : year - 1
      scope = Payslip.where(employee_id: employee_ids)
        .where("year > :first OR (year = :first AND month >= 4)", first: start_year)
        .where("year < :last OR (year = :last AND month <= :month)", last: year, month: month)
      totals = scope.group(:employee_id).pluck(:employee_id, Arel.sql("SUM(gross_pay)"), Arel.sql("SUM(net_pay)"))
        .to_h { |id, gross, net| [ id, { gross: gross, net: net, pf: 0.to_d, tds: 0.to_d } ] }
      pf_names = [ "PF", "EPF", "Provident Fund" ]
      tds_names = [ "TDS", "Income Tax (TDS)", "Income Tax" ]
      PayslipLineItem.joins(:payslip).where(payslip_id: scope.select(:id), component_name: pf_names + tds_names)
        .group("payslips.employee_id", :component_name).sum(:amount).each do |(id, name), amount|
        totals.fetch(id)[pf_names.include?(name) ? :pf : :tds] += amount
      end
      totals
    end
  end
end
