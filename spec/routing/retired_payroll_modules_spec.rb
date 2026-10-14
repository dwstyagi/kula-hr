require "rails_helper"

RSpec.describe "Retired payroll modules", type: :routing do
  %w[off_cycle_payroll_runs full_and_final_payroll_runs].each do |resource|
    it "does not expose #{resource} endpoints" do
      expect(get: "/admin/#{resource}").not_to be_routable
      expect(get: "/admin/#{resource}/new").not_to be_routable
      expect(post: "/admin/#{resource}").not_to be_routable
      expect(get: "/admin/#{resource}/1").not_to be_routable
      expect(patch: "/admin/#{resource}/1/approve").not_to be_routable
      expect(post: "/admin/#{resource}/1/process_payroll").not_to be_routable
    end
  end
end
