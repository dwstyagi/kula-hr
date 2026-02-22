# Pagy initializer
# https://ddnexus.github.io/pagy/docs/api/initializer

# Default items per page
Pagy.options[:limit] = 10

# Load `series` (normally lazy-loaded via series_nav) so our custom Tailwind nav
# partial can call pagy_series(pagy) via ApplicationHelper#pagy_series.
require "pagy/toolbox/helpers/support/series"
