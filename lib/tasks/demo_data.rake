# frozen_string_literal: true

# Builds a complete demo company — tenant, employees, salaries, attendance,
# and fully paid payroll runs — using the app's own services so every
# validation and statutory calculation runs exactly as it does in production.
#
# Idempotent: safe to re-run. Months that already have a PayrollRun are skipped.
#
# Usage:
#   bin/rails demo:payroll
#   SUBDOMAIN=sunrise COMPANY="Sunrise Corp" STATE=Maharashtra bin/rails demo:payroll
#   START_MONTH=2026-04 MONTHS=3 bin/rails demo:payroll
#
# Production requires explicit passwords:
#   DEMO_ADMIN_PASSWORD=... [PLATFORM_ADMIN_PASSWORD=...] bin/rails demo:payroll
namespace :demo do
  desc "Create a demo tenant with employees, salaries, attendance and paid payroll runs"
  task payroll: :environment do
    subdomain    = ENV.fetch("SUBDOMAIN", "demo")
    company_name = ENV.fetch("COMPANY", "Meridian Software Pvt Ltd")
    state        = ENV.fetch("STATE", "Karnataka")
    admin_email  = ENV.fetch("ADMIN_EMAIL", "admin@#{subdomain}.com")
    start_month  = Date.strptime(ENV.fetch("START_MONTH", "2026-04"), "%Y-%m")
    month_count  = Integer(ENV.fetch("MONTHS", "3"))

    admin_password = ENV["DEMO_ADMIN_PASSWORD"]
    if admin_password.blank?
      abort "DEMO_ADMIN_PASSWORD is required in production" if Rails.env.production?
      admin_password = "password123"
    end

    # ── Phase 0: Platform admin ──────────────────────────────────────────────
    if PlatformAdmin.none?
      platform_password = ENV["PLATFORM_ADMIN_PASSWORD"]
      if platform_password.blank?
        abort "PLATFORM_ADMIN_PASSWORD is required in production" if Rails.env.production?
        platform_password = "password123"
      end
      PlatformAdmin.create!(
        first_name: "Platform", last_name: "Admin",
        email: "admin@kulahr.com",
        password: platform_password, password_confirmation: platform_password
      )
      puts "Created platform admin: admin@kulahr.com"
    end

    # ── Phase 1: Tenant via onboarder (payroll settings, components, leave types, PT slabs) ──
    tenant = Tenant.find_by(subdomain: subdomain)
    if tenant.nil?
      form = SignupForm.new(
        company_name: company_name, subdomain: subdomain, state: state,
        first_name: "#{company_name.split.first}", last_name: "Admin",
        email: admin_email,
        password: admin_password, password_confirmation: admin_password
      )
      result = Tenants::TenantOnboarder.call(form)
      abort "Tenant onboarding failed: #{result.error}" unless result.success?
      tenant = result.tenant
      tenant.update!(
        status: "active",
        pan: "AABCM4321K", tan: "BLRM54321A", gstin: "29AABCM4321K1Z7",
        pf_establishment_code: "KABLR0054321000", esi_code: "53009876540000888",
        address: "88 Residency Road", city: "Bengaluru", pincode: "560025"
      )
      puts "Created tenant: #{company_name} (#{subdomain})"
    else
      puts "Tenant '#{subdomain}' already exists — reusing"
    end

    admin_user = tenant.users.find_by(email: admin_email) || tenant.users.first
    abort "No admin user found for tenant" unless admin_user

    # ── Phase 1b: HR admin user ─────────────────────────────────────────────
    # The onboarder's user holds super_admin; this adds a second admin with the
    # hr_admin role (mirrors Admin::AdminUsersController#create, activated
    # directly instead of via email invite).
    hr_email = "hr@#{subdomain}.com"
    unless tenant.users.exists?(email: hr_email)
      hr_user = User.create!(
        first_name: "Kavita", last_name: "Desai",
        email: hr_email,
        password: admin_password, password_confirmation: admin_password,
        invitation_accepted_at: Time.current
      )
      TenantUser.create!(tenant: tenant, user: hr_user)
      hr_user.add_role(:hr_admin)
      puts "Created HR admin user: #{hr_email} (hr_admin)"
    end

    ActsAsTenant.with_tenant(tenant) do
      # ── Phase 2: Org structure + employees ─────────────────────────────────
      %w[Engineering Design Product Marketing Sales HR Finance Support Operations].each do |name|
        Department.find_or_create_by!(name: name)
      end
      [
        "Software Engineer", "Senior Software Engineer", "Tech Lead",
        "Engineering Manager", "Product Designer", "Product Manager",
        "Marketing Manager", "Sales Executive", "HR Manager", "Finance Manager", "Intern",
        "QA Engineer", "DevOps Engineer", "Marketing Executive", "HR Executive",
        "Accountant", "Support Engineer", "Office Assistant"
      ].each { |name| Designation.find_or_create_by!(name: name) }

      dept = ->(name) { Department.find_by!(name: name) }
      desg = ->(name) { Designation.find_by!(name: name) }

      # All joining dates precede the first payroll month so nobody is paid
      # for a month before they joined. annual_ctc drives realistic payslips;
      # the intern stays under the ₹21k ESI gross ceiling.
      employees_data = [
        { first_name: "Sunita", last_name: "Rao", email: "sunita.rao@#{subdomain}.com", gender: "female", department: "HR", designation: "HR Manager", joining_date: Date.new(2023, 6, 1), employment_status: "active", annual_ctc: 1_800_000, pan_number: "AAJPS1234R", bank_name: "HDFC Bank", bank_account_number: "50100123456701", ifsc_code: "HDFC0001234" },
        { first_name: "Rajesh", last_name: "Iyer", email: "rajesh.iyer@#{subdomain}.com", gender: "male", department: "Finance", designation: "Finance Manager", joining_date: Date.new(2023, 6, 1), employment_status: "active", annual_ctc: 2_000_000, pan_number: "AAKRI5678Y", bank_name: "State Bank of India", bank_account_number: "20123456789002", ifsc_code: "SBIN0001234" },
        { first_name: "Rahul", last_name: "Sharma", email: "rahul.sharma@#{subdomain}.com", gender: "male", department: "Engineering", designation: "Engineering Manager", joining_date: Date.new(2024, 3, 1), employment_status: "active", annual_ctc: 3_200_000, pan_number: "ABCRS1234F", bank_name: "ICICI Bank", bank_account_number: "123456789003", ifsc_code: "ICIC0001234" },
        { first_name: "Neha", last_name: "Singh", email: "neha.singh@#{subdomain}.com", gender: "female", department: "Product", designation: "Product Manager", joining_date: Date.new(2024, 5, 1), employment_status: "active", annual_ctc: 2_800_000, pan_number: "AACNS5678G", bank_name: "Axis Bank", bank_account_number: "91601001234004", ifsc_code: "UTIB0001234" },
        { first_name: "Meera", last_name: "Nair", email: "meera.nair@#{subdomain}.com", gender: "female", department: "Marketing", designation: "Marketing Manager", joining_date: Date.new(2024, 7, 1), employment_status: "active", annual_ctc: 2_200_000, pan_number: "AADMN9012H", bank_name: "Kotak Mahindra Bank", bank_account_number: "1234567890005", ifsc_code: "KKBK0001234" },
        { first_name: "Arun", last_name: "Krishnan", email: "arun.krishnan@#{subdomain}.com", gender: "male", department: "Sales", designation: "Sales Executive", joining_date: Date.new(2024, 11, 1), employment_status: "active", annual_ctc: 1_200_000, pan_number: "AAEAK3456J", bank_name: "HDFC Bank", bank_account_number: "50100987654006", ifsc_code: "HDFC0005678" },
        { first_name: "Vikram", last_name: "Malhotra", email: "vikram.malhotra@#{subdomain}.com", gender: "male", department: "Engineering", designation: "Tech Lead", joining_date: Date.new(2024, 4, 1), employment_status: "active", annual_ctc: 2_600_000, pan_number: "AAFVM7890K", bank_name: "ICICI Bank", bank_account_number: "987654321007", ifsc_code: "ICIC0005678", manager_email: "rahul.sharma@#{subdomain}.com" },
        { first_name: "Priya", last_name: "Patel", email: "priya.patel@#{subdomain}.com", gender: "female", department: "Engineering", designation: "Senior Software Engineer", joining_date: Date.new(2024, 12, 1), employment_status: "active", annual_ctc: 2_100_000, pan_number: "AAGPP2345L", bank_name: "State Bank of India", bank_account_number: "30567890123008", ifsc_code: "SBIN0005678", manager_email: "vikram.malhotra@#{subdomain}.com" },
        { first_name: "Aditya", last_name: "Kumar", email: "aditya.kumar@#{subdomain}.com", gender: "male", department: "Engineering", designation: "Software Engineer", joining_date: Date.new(2025, 6, 1), employment_status: "active", annual_ctc: 1_400_000, pan_number: "AAHAK6789M", bank_name: "Axis Bank", bank_account_number: "91601008765009", ifsc_code: "UTIB0005678", manager_email: "vikram.malhotra@#{subdomain}.com" },
        { first_name: "Rohan", last_name: "Gupta", email: "rohan.gupta@#{subdomain}.com", gender: "male", department: "Engineering", designation: "Software Engineer", joining_date: Date.new(2025, 6, 1), employment_status: "active", annual_ctc: 1_300_000, pan_number: "AAIRG0123N", bank_name: "HDFC Bank", bank_account_number: "50100456789010", ifsc_code: "HDFC0009012", manager_email: "vikram.malhotra@#{subdomain}.com" },
        { first_name: "Ananya", last_name: "Verma", email: "ananya.verma@#{subdomain}.com", gender: "female", department: "Design", designation: "Product Designer", joining_date: Date.new(2025, 5, 1), employment_status: "active", annual_ctc: 1_600_000, pan_number: "AAJAV4567P", bank_name: "Kotak Mahindra Bank", bank_account_number: "9876543210011", ifsc_code: "KKBK0005678", manager_email: "neha.singh@#{subdomain}.com" },
        { first_name: "Pooja", last_name: "Mehta", email: "pooja.mehta@#{subdomain}.com", gender: "female", department: "Engineering", designation: "Software Engineer", joining_date: Date.new(2026, 2, 2), employment_status: "probation", annual_ctc: 1_000_000, pan_number: "AAKPM8901Q", bank_name: "ICICI Bank", bank_account_number: "345678901012", ifsc_code: "ICIC0009012", manager_email: "vikram.malhotra@#{subdomain}.com" },
        { first_name: "Kiran", last_name: "Joshi", email: "kiran.joshi@#{subdomain}.com", gender: "male", department: "Engineering", designation: "Intern", joining_date: Date.new(2026, 3, 2), employment_status: "probation", annual_ctc: 220_000, pan_number: "AALKJ2345R", bank_name: "State Bank of India", bank_account_number: "40890123456013", ifsc_code: "SBIN0009012", manager_email: "priya.patel@#{subdomain}.com" }
      ]

      employees = {}
      employees_data.each do |attrs|
        attrs = attrs.dup
        manager_email = attrs.delete(:manager_email)
        annual_ctc    = attrs.delete(:annual_ctc)
        emp = Employee.find_or_initialize_by(email: attrs[:email])
        if emp.new_record?
          emp.assign_attributes(
            attrs.merge(department: dept.(attrs[:department]), designation: desg.(attrs[:designation]))
          )
          emp.reporting_manager = employees[manager_email]&.first
          emp.save!
        end
        employees[attrs[:email]] = [ emp, annual_ctc ]
      end

      # ── Phase 2b: bulk roster ────────────────────────────────────────────────
      # Deterministically generated staff (seeded RNG) so re-runs produce the
      # same people. CTC bands are per-designation; Office Assistants sit under
      # the ₹21k ESI gross ceiling so ESI shows up beyond the intern.
      first_names = {
        "male"   => %w[Aarav Vihaan Arjun Sai Reyansh Ishaan Shaurya Atharv Kabir Ritvik
                       Aayush Dhruv Karthik Manish Nikhil Pranav Raghav Sandeep Tarun Uday
                       Varun Yash Harish Gaurav Deepak Chetan Bharat Mohit Sameer Tejas],
        "female" => %w[Aadhya Diya Ira Kavya Kiara Myra Navya Pari Riya Saanvi
                       Sara Tara Vanya Ishita Jhanvi Lakshmi Mira Nisha Ritu Shreya]
      }
      surnames = %w[Sharma Verma Gupta Malhotra Bhatia Khanna Kapoor Chopra Reddy Naidu
                    Rao Nair Menon Pillai Iyer Das Bose Sen Mukherjee Banerjee
                    Patel Shah Mehta Desai Kulkarni Deshpande Joshi Kumar Singh Agarwal]
      banks = [
        [ "HDFC Bank", "HDFC0002211" ], [ "ICICI Bank", "ICIC0002211" ],
        [ "State Bank of India", "SBIN0002211" ], [ "Axis Bank", "UTIB0002211" ],
        [ "Kotak Mahindra Bank", "KKBK0002211" ]
      ]
      # [department, designation, CTC band, headcount, manager email]
      staffing = [
        [ "Engineering", "Software Engineer",        900_000..1_500_000, 14, "vikram.malhotra@#{subdomain}.com" ],
        [ "Engineering", "Senior Software Engineer", 1_600_000..2_400_000, 8, "rahul.sharma@#{subdomain}.com" ],
        [ "Engineering", "QA Engineer",              700_000..1_200_000,  4, "vikram.malhotra@#{subdomain}.com" ],
        [ "Engineering", "DevOps Engineer",          1_200_000..2_000_000, 3, "rahul.sharma@#{subdomain}.com" ],
        [ "Design",      "Product Designer",         900_000..1_800_000,  3, "neha.singh@#{subdomain}.com" ],
        [ "Product",     "Product Manager",          1_800_000..2_600_000, 2, "neha.singh@#{subdomain}.com" ],
        [ "Marketing",   "Marketing Executive",      500_000..900_000,    4, "meera.nair@#{subdomain}.com" ],
        [ "Sales",       "Sales Executive",          400_000..900_000,    6, "arun.krishnan@#{subdomain}.com" ],
        [ "HR",          "HR Executive",             450_000..800_000,    2, "sunita.rao@#{subdomain}.com" ],
        [ "Finance",     "Accountant",               500_000..900_000,    2, "rajesh.iyer@#{subdomain}.com" ],
        [ "Support",     "Support Engineer",         350_000..600_000,    4, "vikram.malhotra@#{subdomain}.com" ],
        [ "Operations",  "Office Assistant",         220_000..240_000,    2, "sunita.rao@#{subdomain}.com" ]
      ]

      rng = Random.new(2026)
      letters = ("A".."Z").to_a
      generated = 0
      staffing.each do |dept_name, desg_name, ctc_band, headcount, manager_email|
        headcount.times do
          # Every rng draw happens unconditionally (and in a fixed order) so
          # the sequence — and therefore each person's identity — is identical
          # on re-runs even when some employees already exist.
          gender  = rng.rand < 0.6 ? "male" : "female"
          first   = first_names[gender].sample(random: rng)
          last    = surnames.sample(random: rng)
          email   = "#{first.downcase}.#{last.downcase}@#{subdomain}.com"
          email   = "#{first.downcase}.#{last.downcase}#{generated}@#{subdomain}.com" if employees.key?(email)
          joining = Date.new(2023, 1, 1) + rng.rand(0..1150)
          bank, ifsc = banks.sample(random: rng)
          pan     = "#{letters.sample(random: rng)}#{letters.sample(random: rng)}#{letters.sample(random: rng)}P#{last[0]}#{1000 + generated * 13}#{letters.sample(random: rng)}"
          annual_ctc = ((rng.rand(ctc_band) / 10_000) * 10_000)

          emp = Employee.find_or_initialize_by(email: email)
          if emp.new_record?
            emp.assign_attributes(
              first_name: first, last_name: last, gender: gender,
              department: dept.(dept_name), designation: desg.(desg_name),
              joining_date: joining,
              employment_status: joining >= Date.new(2026, 1, 1) ? "probation" : "active",
              pan_number: pan, bank_name: bank, ifsc_code: ifsc,
              bank_account_number: (50_100_200_000_000 + generated * 137).to_s,
              reporting_manager: employees[manager_email]&.first
            )
            emp.save!
          end
          employees[email] = [ emp, annual_ctc ]
          generated += 1
        end
      end
      puts "Employees in place: #{employees.size} (13 named + #{generated} generated)"

      # ── Phase 2c: Employee portal accounts ──────────────────────────────────
      # Mirrors Employees::SelfActivationService but activates directly (known
      # password, invitation marked accepted) instead of emailing an invite.
      activated = 0
      employees.each_value do |(emp, _)|
        next if emp.user
        portal_user = User.create!(
          first_name: emp.first_name, last_name: emp.last_name,
          email: emp.email,
          password: admin_password, password_confirmation: admin_password,
          invitation_accepted_at: Time.current
        )
        TenantUser.create!(tenant: tenant, user: portal_user)
        portal_user.assign_role(:employee)
        emp.update!(user: portal_user)
        activated += 1
      end
      puts "Portal accounts activated: #{activated} new (#{employees.size} total)"

      # ── Phase 2d: Work locations + holidays ─────────────────────────────────
      # Holidays reduce each location's working days (WorkingDaysCalculator),
      # so a holiday is a paid day off. nil work_location = company-wide.
      # Basava Jayanti (May, Bengaluru-only) lands inside the default payroll
      # window so location-specific working days visibly differ.
      wl = {}
      [ [ "Bengaluru HQ", "Karnataka" ], [ "Mumbai Office", "Maharashtra" ], [ "Remote", nil ] ].each do |name, wl_state|
        wl[name] = WorkLocation.find_or_create_by!(name: name) { |l| l.state = wl_state }
      end

      assignment_cycle = [
        "Bengaluru HQ", "Bengaluru HQ", "Mumbai Office", "Bengaluru HQ", "Remote",
        "Bengaluru HQ", "Mumbai Office", "Bengaluru HQ", "Bengaluru HQ", "Remote"
      ]
      employees.each_value.with_index do |(emp, _), idx|
        next if emp.work_location_id
        emp.update!(work_location: wl[assignment_cycle[idx % assignment_cycle.size]])
      end

      hyear = start_month.year
      holiday_calendar = {
        nil => [
          [ "New Year's Day", 1, 1 ], [ "Republic Day", 1, 26 ], [ "Holi", 3, 4 ],
          [ "Dr. Ambedkar Jayanti", 4, 14 ], [ "May Day", 5, 1 ],
          [ "Independence Day", 8, 15 ], [ "Gandhi Jayanti", 10, 2 ],
          [ "Diwali", 11, 9 ], [ "Christmas", 12, 25 ]
        ],
        "Bengaluru HQ" => [
          [ "Ugadi", 3, 19 ], [ "Basava Jayanti", 5, 20 ], [ "Kannada Rajyotsava", 11, 1 ]
        ],
        "Mumbai Office" => [
          [ "Gudi Padwa", 3, 19 ], [ "Ganesh Chaturthi", 9, 14 ]
        ]
      }
      new_holidays = 0
      holiday_calendar.each do |loc_name, list|
        list.each do |(hname, m, d)|
          holiday = Holiday.find_or_create_by!(date: Date.new(hyear, m, d), work_location: loc_name && wl[loc_name]) do |h|
            h.name = hname
          end
          new_holidays += 1 if holiday.previously_new_record?
        end
      end
      puts "Work locations: #{wl.size} | Holidays: #{new_holidays} new (#{Holiday.count} total for #{hyear})"

      # ── Phase 3: Salary structure + assignments ─────────────────────────────
      structure = SalaryStructure.find_or_create_by!(name: "Standard") do |s|
        s.active = true
      end
      if structure.salary_structure_components.none?
        component_values = {
          "Basic" => 40, "HRA" => 20, "DA" => 5, "Special Allowance" => 30, # % of annual CTC
          "Conveyance Allowance" => 1600, "Medical Allowance" => 1250       # flat ₹/month
        }
        component_values.each do |name, value|
          structure.salary_structure_components.create!(
            salary_component: SalaryComponent.find_by!(name: name), value: value
          )
        end
        puts "Created salary structure 'Standard' (#{component_values.size} components)"
      end

      employees.each_value do |(emp, annual_ctc)|
        next if emp.current_salary
        EmployeeSalary.create!(
          employee: emp, salary_structure: structure,
          annual_ctc: annual_ctc, effective_from: emp.joining_date
        )
      end
      puts "Salaries assigned to all employees"

      # ── Phase 3b: Leave balances + tax declarations ─────────────────────────
      Leave::LeaveBalanceAllocator.new(employees: employees.values.map(&:first)).call

      fy = start_month.month >= 4 ? "#{start_month.year}-#{(start_month.year + 1) % 100}" : "#{start_month.year - 1}-#{start_month.year % 100}"
      old_regime = {
        "sunita.rao@#{subdomain}.com"  => [ { section: "80C", description: "PPF + ELSS", declared_amount: 150_000 }, { section: "80D", description: "Health insurance premium", declared_amount: 25_000 } ],
        "rajesh.iyer@#{subdomain}.com" => [ { section: "80C", description: "Life insurance + EPF top-up", declared_amount: 150_000 } ],
        "priya.patel@#{subdomain}.com" => [ { section: "80C", description: "ELSS mutual funds", declared_amount: 100_000 } ]
      }
      employees.each_value do |(emp, _)|
        next if emp.tax_declarations.exists?(financial_year: fy)
        investments = old_regime[emp.email]
        emp.tax_declarations.create!(
          financial_year: fy,
          regime: investments ? :old_regime : :new_regime,
          status: :submitted,
          investment_declarations_attributes: (investments || []).map { |i| i.merge(tenant_id: tenant.id) }
        )
      end
      puts "Tax declarations in place (FY #{fy})"

      # ── Phases 4–5: attendance + payroll, month by month ────────────────────
      # A couple of employees lose a day or take a half day each month so
      # proration and LOP actually show up on payslips.
      variance = [
        { "aditya.kumar@#{subdomain}.com" => { days_off: 1 }, "arun.krishnan@#{subdomain}.com" => { half_days: 1 } },
        { "rohan.gupta@#{subdomain}.com" => { days_off: 2 }, "ananya.verma@#{subdomain}.com" => { half_days: 1 } },
        { "pooja.mehta@#{subdomain}.com" => { days_off: 1 }, "priya.patel@#{subdomain}.com" => { half_days: 1 } }
      ]

      month_count.times do |i|
        period = start_month >> i
        month, year = period.month, period.year

        if PayrollRun.for_month(month, year).exists?
          puts "#{Date::MONTHNAMES[month]} #{year}: payroll run already exists — skipping"
          next
        end

        Attendance::SummaryGenerator.new(month: month, year: year, tenant: tenant).call

        variance[i % variance.size].each do |email, tweak|
          summary = AttendanceSummary.for_month(month, year).find_by(employee: employees[email].first)
          next unless summary
          summary.update!(
            days_present: summary.days_present - tweak.fetch(:days_off, 0),
            half_days: tweak.fetch(:half_days, 0)
          )
        end

        AttendanceSummary.for_month(month, year).find_each { |s| s.update!(status: :locked) }

        run = PayrollRun.create!(month: month, year: year, initiated_by: admin_user)
        result = Payroll::PayrollProcessor.new(payroll_run: run).call

        run.submit_for_review!
        run.approve!
        run.record_approval(admin_user)
        run.mark_paid!

        # Backdate so the run reads as month-end history, not created-today
        month_end = period.end_of_month
        run.update_columns(
          created_at: month_end.to_time.change(hour: 10),
          approved_at: (month_end + 1).to_time.change(hour: 15),
          updated_at: (month_end + 2).to_time.change(hour: 11)
        )

        skipped = result.errors.map { |e| "#{e[:name]} (#{e[:error]})" }
        puts "#{Date::MONTHNAMES[month]} #{year}: paid — #{result.processed.size} payslips, " \
             "gross ₹#{run.reload.total_gross.to_f.round}, net ₹#{run.total_net_pay.to_f.round}" \
             "#{skipped.any? ? ", skipped: #{skipped.join('; ')}" : ''}"
      end
    end

    puts "\nDone. Log in:"
    puts "  Super admin:  http://#{subdomain}.lvh.me:3000/admin  (#{admin_email})"
    puts "  HR admin:     http://#{subdomain}.lvh.me:3000/admin  (#{hr_email})"
    puts "  Platform:     http://lvh.me:3000/platform_admin  (admin@kulahr.com)"
  end
end
