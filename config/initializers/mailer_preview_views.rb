# Override the default ActionMailer preview UI with our custom templates.
# Rails::MailersController uses its own isolated view path (railties/lib/rails/templates/)
# and never checks app/views, so we must inject our path explicitly.
Rails.application.config.to_prepare do
  Rails::MailersController.prepend_view_path Rails.root.join("app/views")
end
