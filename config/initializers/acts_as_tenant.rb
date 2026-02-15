# Platform admin operates without a tenant, so we can't require one globally.
ActsAsTenant.configure do |config|
  config.require_tenant = false
end
