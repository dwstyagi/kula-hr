class Admin::PayrollSettingsController < Admin::BaseController
  before_action :set_payroll_setting

  def show
    authorize @payroll_setting
  end

  def edit
    authorize @payroll_setting
  end

  def update
    authorize @payroll_setting
    if @payroll_setting.update(payroll_setting_params)
      redirect_to admin_payroll_setting_path, notice: "Payroll settings saved."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_payroll_setting
    @payroll_setting = PayrollSetting.find_by!(tenant: current_tenant)
  end

  def payroll_setting_params
    params.require(:payroll_setting).permit(
      :pf_enabled, :pf_employee_rate, :pf_employer_rate, :pf_wage_ceiling,
      :pf_include_da, :pf_admin_charge_rate, :pf_edli_rate,
      :employer_pf_in_ctc, :hide_employer_contributions_on_slip,
      :esi_enabled, :esi_employee_rate, :esi_employer_rate, :esi_ceiling,
      :pt_enabled, :pt_state,
      :tds_enabled,
      :week_off_pattern
    )
  end
end
