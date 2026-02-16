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
    end
  else
    puts "  ERROR creating tenant: #{result.error}"
  end
else
  puts "  Tenant 'acme' already exists"
end

puts "Seeding complete!"
