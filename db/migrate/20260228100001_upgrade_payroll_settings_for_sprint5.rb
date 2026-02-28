class UpgradePayrollSettingsForSprint5 < ActiveRecord::Migration[8.1]
  def change
    rename_column :payroll_settings, :pf_ceiling, :pf_wage_ceiling
    rename_column :payroll_settings, :state, :pt_state

    add_column :payroll_settings, :pf_enabled,          :boolean, default: true,  null: false
    add_column :payroll_settings, :pf_include_da,        :boolean, default: true,  null: false
    add_column :payroll_settings, :pf_admin_charge_rate, :decimal, precision: 5, scale: 2, default: 0.50, null: false
    add_column :payroll_settings, :pf_edli_rate,         :decimal, precision: 5, scale: 2, default: 0.50, null: false
    add_column :payroll_settings, :esi_enabled,          :boolean, default: true,  null: false
    add_column :payroll_settings, :pt_enabled,           :boolean, default: true,  null: false
    add_column :payroll_settings, :tds_enabled,          :boolean, default: true,  null: false
  end
end
