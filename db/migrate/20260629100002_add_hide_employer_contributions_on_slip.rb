class AddHideEmployerContributionsOnSlip < ActiveRecord::Migration[8.1]
  def change
    # Display-only: when true, the payslip omits the employer-contribution
    # itemisation and shows the carved gross as "CTC" (the net-of-employer-PF
    # figure). Pairs with employer_pf_in_ctc. Default false (transparent).
    add_column :payroll_settings, :hide_employer_contributions_on_slip, :boolean, default: false, null: false
  end
end
