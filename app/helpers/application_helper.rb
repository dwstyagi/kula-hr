module ApplicationHelper
  # Exposes Pagy's protected `series` method for use in custom Tailwind nav partials.
  def pagy_series(pagy, **options)
    pagy.send(:series, **options)
  end
end
