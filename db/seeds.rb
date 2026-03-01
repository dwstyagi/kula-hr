# frozen_string_literal: true

puts "Seeding database..."

# 1. Platform Admin
platform_admin = PlatformAdmin.find_or_initialize_by(email: "admin@kulahr.com")
if platform_admin.new_record?
  platform_admin.update!(
    first_name: "Platform",
    last_name: "Admin",
    password: "password123",
    password_confirmation: "password123"
  )
  puts "  Created platform admin: admin@kulahr.com / password123"
else
  puts "  Platform admin already exists: admin@kulahr.com"
end

# 2. Sample Tenant via TenantOnboarder
unless Tenant.exists?(subdomain: "acme")
  form = SignupForm.new(
    company_name: "Acme Corporation",
    subdomain: "acme",
    first_name: "Acme",
    last_name: "Admin",
    email: "admin@acme.com",
    password: "password123",
    password_confirmation: "password123",
    state: "Maharashtra"
  )

  result = Tenants::TenantOnboarder.call(form)

  if result.success?
    puts "  Created tenant: Acme Corporation (acme.lvh.me:3000)"
    puts "  Created tenant admin: admin@acme.com / password123"

    tenant = result.tenant

    # 3. Sample Departments
    departments = %w[Engineering Design Product Marketing Sales HR Finance]
    ActsAsTenant.with_tenant(tenant) do
      departments.each do |name|
        Department.find_or_create_by!(name: name)
      end
      puts "  Created #{departments.size} departments"

      # 4. Sample Designations
      designations = [
        "Software Engineer",
        "Senior Software Engineer",
        "Tech Lead",
        "Engineering Manager",
        "Product Designer",
        "Product Manager",
        "Marketing Manager",
        "Sales Executive",
        "HR Manager",
        "Finance Manager",
        "Intern"
      ]
      designations.each do |name|
        Designation.find_or_create_by!(name: name)
      end
      puts "  Created #{designations.size} designations"

      # 5. Sample Employees
      eng  = Department.find_by!(name: "Engineering")
      des  = Department.find_by!(name: "Design")
      prod = Department.find_by!(name: "Product")
      mkt  = Department.find_by!(name: "Marketing")
      sal  = Department.find_by!(name: "Sales")
      hr   = Department.find_by!(name: "HR")
      fin  = Department.find_by!(name: "Finance")

      d = ->(name) { Designation.find_by!(name: name) }

      employees_data = [
        # Managers / leads (no reporting_manager — seeded first)
        { first_name: "Sunita",  last_name: "Rao",       email: "sunita.rao@acme.com",       gender: "female", department: hr,   designation: d.("HR Manager"),               joining_date: 3.years.ago.to_date,   employment_status: "active",    pan_number: "AAJPS1234R", bank_name: "HDFC Bank",           bank_account_number: "50100123456701", ifsc_code: "HDFC0001234" },
        { first_name: "Rajesh",  last_name: "Iyer",      email: "rajesh.iyer@acme.com",       gender: "male",   department: fin,  designation: d.("Finance Manager"),          joining_date: 3.years.ago.to_date,   employment_status: "active",    pan_number: "AAKRI5678Y", bank_name: "State Bank of India", bank_account_number: "20123456789002", ifsc_code: "SBIN0001234" },
        { first_name: "Rahul",   last_name: "Sharma",    email: "rahul.sharma@acme.com",      gender: "male",   department: eng,  designation: d.("Engineering Manager"),      joining_date: 2.years.ago.to_date,   employment_status: "active",    pan_number: "ABCRS1234F", bank_name: "ICICI Bank",          bank_account_number: "123456789003",   ifsc_code: "ICIC0001234" },
        { first_name: "Neha",    last_name: "Singh",     email: "neha.singh@acme.com",        gender: "female", department: prod, designation: d.("Product Manager"),          joining_date: 2.years.ago.to_date,   employment_status: "active",    pan_number: "AACNS5678G", bank_name: "Axis Bank",           bank_account_number: "91601001234004", ifsc_code: "UTIB0001234" },
        { first_name: "Meera",   last_name: "Nair",      email: "meera.nair@acme.com",        gender: "female", department: mkt,  designation: d.("Marketing Manager"),        joining_date: 2.years.ago.to_date,   employment_status: "active",    pan_number: "AADMN9012H", bank_name: "Kotak Mahindra Bank", bank_account_number: "1234567890005",  ifsc_code: "KKBK0001234" },
        { first_name: "Arun",    last_name: "Krishnan",  email: "arun.krishnan@acme.com",     gender: "male",   department: sal,  designation: d.("Sales Executive"),          joining_date: 18.months.ago.to_date, employment_status: "active",    pan_number: "AAEAK3456J", bank_name: "HDFC Bank",           bank_account_number: "50100987654006", ifsc_code: "HDFC0005678" },

        # Tech lead reporting to Engineering Manager
        { first_name: "Vikram",  last_name: "Malhotra",  email: "vikram.malhotra@acme.com",   gender: "male",   department: eng,  designation: d.("Tech Lead"),                joining_date: 2.years.ago.to_date,   employment_status: "active",    pan_number: "AAFVM7890K", bank_name: "ICICI Bank",          bank_account_number: "987654321007",   ifsc_code: "ICIC0005678", manager_email: "rahul.sharma@acme.com" },

        # ICs reporting to Tech Lead
        { first_name: "Priya",   last_name: "Patel",     email: "priya.patel@acme.com",       gender: "female", department: eng,  designation: d.("Senior Software Engineer"), joining_date: 18.months.ago.to_date, employment_status: "active",    pan_number: "AAGPP2345L", bank_name: "State Bank of India", bank_account_number: "30567890123008", ifsc_code: "SBIN0005678", manager_email: "vikram.malhotra@acme.com" },
        { first_name: "Aditya",  last_name: "Kumar",     email: "aditya.kumar@acme.com",      gender: "male",   department: eng,  designation: d.("Software Engineer"),        joining_date: 1.year.ago.to_date,    employment_status: "active",    pan_number: "AAHAK6789M", bank_name: "Axis Bank",           bank_account_number: "91601008765009", ifsc_code: "UTIB0005678", manager_email: "vikram.malhotra@acme.com" },
        { first_name: "Rohan",   last_name: "Gupta",     email: "rohan.gupta@acme.com",       gender: "male",   department: eng,  designation: d.("Software Engineer"),        joining_date: 1.year.ago.to_date,    employment_status: "active",    pan_number: "AAIRG0123N", bank_name: "HDFC Bank",           bank_account_number: "50100456789010", ifsc_code: "HDFC0009012", manager_email: "vikram.malhotra@acme.com" },

        # Designer reporting to Product Manager
        { first_name: "Ananya",  last_name: "Verma",     email: "ananya.verma@acme.com",      gender: "female", department: des,  designation: d.("Product Designer"),         joining_date: 14.months.ago.to_date, employment_status: "active",    pan_number: "AAJAV4567P", bank_name: "Kotak Mahindra Bank", bank_account_number: "9876543210011",  ifsc_code: "KKBK0005678", manager_email: "neha.singh@acme.com" },

        # Probation employees
        { first_name: "Pooja",   last_name: "Mehta",     email: "pooja.mehta@acme.com",       gender: "female", department: eng,  designation: d.("Software Engineer"),        joining_date: 2.months.ago.to_date,  employment_status: "probation", pan_number: "AAKPM8901Q", bank_name: "ICICI Bank",          bank_account_number: "345678901012",   ifsc_code: "ICIC0009012", manager_email: "vikram.malhotra@acme.com" },
        { first_name: "Kiran",   last_name: "Joshi",     email: "kiran.joshi@acme.com",       gender: "male",   department: eng,  designation: d.("Intern"),                   joining_date: 1.month.ago.to_date,   employment_status: "probation", pan_number: "AALKJ2345R", bank_name: "State Bank of India", bank_account_number: "40890123456013", ifsc_code: "SBIN0009012", manager_email: "priya.patel@acme.com" },
      ]

      BANK_FIELDS = %i[bank_name bank_account_number ifsc_code].freeze

      created_employees = {}

      employees_data.each do |attrs|
        manager_email = attrs.delete(:manager_email)
        emp = Employee.find_or_initialize_by(email: attrs[:email])
        if emp.new_record?
          emp.assign_attributes(attrs)
          emp.reporting_manager = created_employees[manager_email] if manager_email
        else
          # Always backfill bank details so existing records get them on re-seed
          emp.assign_attributes(attrs.slice(*BANK_FIELDS))
        end
        emp.save!
        created_employees[attrs[:email]] = emp
      end

      puts "  Created #{created_employees.size} employees"
    end
  else
    puts "  ERROR creating tenant: #{result.error}"
  end
else
  puts "  Tenant 'acme' already exists"
end

puts "Seeding complete!"
