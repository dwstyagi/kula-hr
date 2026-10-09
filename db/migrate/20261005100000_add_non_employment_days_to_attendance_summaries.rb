# Days in the month before joining or after the last working day. Kept apart
# from LOP so a mid-month joiner is paid for days employed without showing
# the days before joining as absences.
class AddNonEmploymentDaysToAttendanceSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :attendance_summaries, :non_employment_days, :decimal,
               precision: 5, scale: 1, default: 0, null: false
  end
end
