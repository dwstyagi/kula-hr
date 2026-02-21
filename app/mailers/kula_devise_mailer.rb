class KulaDeviseMailer < Devise::Mailer
  def invitation_instructions(record, token, opts = {})
    @tenant = record.tenants.first
    super
  end

  def url_options
    if @tenant
      domain = ENV.fetch("APP_DOMAIN", "lvh.me")
      options = { host: "#{@tenant.subdomain}.#{domain}" }
      options[:port] = ENV.fetch("PORT", 3000).to_i if Rails.env.development?
      super.merge(options)
    else
      super
    end
  end
end
