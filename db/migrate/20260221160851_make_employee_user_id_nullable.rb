class MakeEmployeeUserIdNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :employees, :user_id, true
  end
end
