# Onboarding seeded "Conveyance Allowance" and "Medical Allowance" as
# non-taxable. Both have been taxable salary since FY 2018-19, and until now
# payroll ignored the flag, so these components were always taxed. TDS now
# honours the flag; flipping the seeded defaults keeps existing TDS unchanged.
class MarkConveyanceAndMedicalAllowancesTaxable < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE salary_components
         SET taxable = TRUE, updated_at = CURRENT_TIMESTAMP
       WHERE component_type = 'earning'
         AND name IN ('Conveyance Allowance', 'Medical Allowance')
         AND taxable = FALSE
    SQL
  end

  def down
    # Irreversible in intent: the old value was a seeding mistake.
  end
end
