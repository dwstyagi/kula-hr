class AddWeekOffSettingsToPayrollSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :payroll_settings, :week_off_pattern, :string, default: "all_saturdays_sundays", null: false
    add_column :payroll_settings, :pro_rate_leaves, :boolean, default: true, null: false
  end
end
