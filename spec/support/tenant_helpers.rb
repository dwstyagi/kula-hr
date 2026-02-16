module TenantHelpers
  def set_tenant(tenant)
    ActsAsTenant.current_tenant = tenant
  end

  def with_tenant(tenant, &block)
    ActsAsTenant.with_tenant(tenant, &block)
  end
end

RSpec.configure do |config|
  config.include TenantHelpers

  config.after(:each) do
    ActsAsTenant.current_tenant = nil
  end
end
