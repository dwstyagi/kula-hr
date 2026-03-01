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
        { first_name: "Sunita",  last_name: "Rao",       email: "sunita.rao@acme.com",       gender: "female", department: hr,   designation: d.("HR Manager"),           joining_date: 3.years.ago.to_date,  employment_status: "active",    pan_number: "AAJPS1234R" },
        { first_name: "Rajesh",  last_name: "Iyer",      email: "rajesh.iyer@acme.com",       gender: "male",   department: fin,  designation: d.("Finance Manager"),      joining_date: 3.years.ago.to_date,  employment_status: "active",    pan_number: "AAKRI5678Y" },
        { first_name: "Rahul",   last_name: "Sharma",    email: "rahul.sharma@acme.com",      gender: "male",   department: eng,  designation: d.("Engineering Manager"),  joining_date: 2.years.ago.to_date,  employment_status: "active",    pan_number: "ABCRS1234F" },
        { first_name: "Neha",    last_name: "Singh",     email: "neha.singh@acme.com",        gender: "female", department: prod, designation: d.("Product Manager"),      joining_date: 2.years.ago.to_date,  employment_status: "active",    pan_number: "AACNS5678G" },
        { first_name: "Meera",   last_name: "Nair",      email: "meera.nair@acme.com",        gender: "female", department: mkt,  designation: d.("Marketing Manager"),    joining_date: 2.years.ago.to_date,  employment_status: "active",    pan_number: "AADMN9012H" },
        { first_name: "Arun",    last_name: "Krishnan",  email: "arun.krishnan@acme.com",     gender: "male",   department: sal,  designation: d.("Sales Executive"),      joining_date: 18.months.ago.to_date, employment_status: "active",   pan_number: "AAEAK3456J" },

        # Tech lead reporting to Engineering Manager
        { first_name: "Vikram",  last_name: "Malhotra",  email: "vikram.malhotra@acme.com",   gender: "male",   department: eng,  designation: d.("Tech Lead"),            joining_date: 2.years.ago.to_date,  employment_status: "active",    pan_number: "AAFVM7890K", manager_email: "rahul.sharma@acme.com" },

        # ICs reporting to Tech Lead
        { first_name: "Priya",   last_name: "Patel",     email: "priya.patel@acme.com",       gender: "female", department: eng,  designation: d.("Senior Software Engineer"), joining_date: 18.months.ago.to_date, employment_status: "active", pan_number: "AAGPP2345L", manager_email: "vikram.malhotra@acme.com" },
        { first_name: "Aditya",  last_name: "Kumar",     email: "aditya.kumar@acme.com",      gender: "male",   department: eng,  designation: d.("Software Engineer"),    joining_date: 1.year.ago.to_date,   employment_status: "active",    pan_number: "AAHAK6789M", manager_email: "vikram.malhotra@acme.com" },
        { first_name: "Rohan",   last_name: "Gupta",     email: "rohan.gupta@acme.com",       gender: "male",   department: eng,  designation: d.("Software Engineer"),    joining_date: 1.year.ago.to_date,   employment_status: "active",    pan_number: "AAIRG0123N", manager_email: "vikram.malhotra@acme.com" },

        # Designer reporting to Product Manager
        { first_name: "Ananya",  last_name: "Verma",     email: "ananya.verma@acme.com",      gender: "female", department: des,  designation: d.("Product Designer"),     joining_date: 14.months.ago.to_date, employment_status: "active",   pan_number: "AAJAV4567P", manager_email: "neha.singh@acme.com" },

        # Probation employees
        { first_name: "Pooja",   last_name: "Mehta",     email: "pooja.mehta@acme.com",       gender: "female", department: eng,  designation: d.("Software Engineer"),    joining_date: 2.months.ago.to_date,  employment_status: "probation", pan_number: "AAKPM8901Q", manager_email: "vikram.malhotra@acme.com" },
        { first_name: "Kiran",   last_name: "Joshi",     email: "kiran.joshi@acme.com",       gender: "male",   department: eng,  designation: d.("Intern"),               joining_date: 1.month.ago.to_date,   employment_status: "probation", pan_number: "AALKJ2345R", manager_email: "priya.patel@acme.com" },
      ]

      created_employees = {}

      employees_data.each do |attrs|
        manager_email = attrs.delete(:manager_email)
        emp = Employee.find_or_initialize_by(email: attrs[:email])
        if emp.new_record?
          emp.assign_attributes(attrs)
          emp.reporting_manager = created_employees[manager_email] if manager_email
          emp.save!
        end
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
