module Admin
  class ReportsController < BaseController
    skip_after_action :verify_authorized
    skip_after_action :verify_policy_scoped

    def index
    end

    # Department Breakdown
    def department_breakdown
      @month = (params[:month] || Date.current.month).to_i
      @year = (params[:year] || Date.current.year).to_i
      @report = Reports::DepartmentBreakdownService.new(month: @month, year: @year).call
    end

    def download_department_csv
      month = (params[:month] || Date.current.month).to_i
      year = (params[:year] || Date.current.year).to_i
      report = Reports::DepartmentBreakdownService.new(month: month, year: year).call
      send_data report.to_csv, filename: "department_breakdown_#{year}_#{month}.csv",
                type: "text/csv", disposition: "attachment"
    end

    # PF Report
    def pf_report
      @month = (params[:month] || Date.current.month).to_i
      @year = (params[:year] || Date.current.year).to_i
      @report = Reports::PfMonthlyReportService.new(month: @month, year: @year).call
    end

    def download_pf_ecr
      month = (params[:month] || Date.current.month).to_i
      year = (params[:year] || Date.current.year).to_i
      report = Reports::PfMonthlyReportService.new(month: month, year: year).call
      send_data report.to_ecr, filename: "pf_ecr_#{year}_#{month}.txt",
                type: "text/plain", disposition: "attachment"
    end

    # ESI Report
    def esi_report
      @month = (params[:month] || Date.current.month).to_i
      @year = (params[:year] || Date.current.year).to_i
      @report = Reports::EsiMonthlyReportService.new(month: @month, year: @year).call
    end

    def download_esi_csv
      month = (params[:month] || Date.current.month).to_i
      year = (params[:year] || Date.current.year).to_i
      report = Reports::EsiMonthlyReportService.new(month: month, year: year).call
      send_data report.to_csv, filename: "esi_report_#{year}_#{month}.csv",
                type: "text/csv", disposition: "attachment"
    end

    # PT Challan
    def pt_challan
      @month = (params[:month] || Date.current.month).to_i
      @year = (params[:year] || Date.current.year).to_i
      @report = Reports::PtChallanReportService.new(month: @month, year: @year).call
    end

    def download_pt_csv
      month = (params[:month] || Date.current.month).to_i
      year = (params[:year] || Date.current.year).to_i
      report = Reports::PtChallanReportService.new(month: month, year: year).call
      send_data report.to_csv, filename: "pt_challan_#{year}_#{month}.csv",
                type: "text/csv", disposition: "attachment"
    end

    # YTD Earnings
    def ytd_earnings
      @financial_year = params[:financial_year] || current_fy
      @report = Reports::YtdEarningsReportService.new(financial_year: @financial_year).call
    end

    def download_ytd_csv
      fy = params[:financial_year] || current_fy
      report = Reports::YtdEarningsReportService.new(financial_year: fy).call
      send_data report.to_csv, filename: "ytd_earnings_#{fy}.csv",
                type: "text/csv", disposition: "attachment"
    end

    private

    def current_fy
      today = Date.current
      if today.month >= 4
        "#{today.year}-#{(today.year + 1).to_s.last(2)}"
      else
        "#{today.year - 1}-#{today.year.to_s.last(2)}"
      end
    end
  end
end
