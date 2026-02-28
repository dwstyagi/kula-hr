class AddStatutoryFlagsToEmployees < ActiveRecord::Migration[8.1]
  def change
    add_column :employees, :pf_applicable,    :boolean, default: true,  null: false
    add_column :employees, :pf_on_full_basic,  :boolean, default: false, null: false
    add_column :employees, :pt_applicable,     :boolean, default: true,  null: false
  end
end
