module ApplicationHelper
  # Exposes Pagy's protected `series` method for use in custom Tailwind nav partials.
  def pagy_series(pagy, **options)
    pagy.send(:series, **options)
  end

  def greeting
    case Time.current.hour
    when 0..11  then "morning"
    when 12..16 then "afternoon"
    else             "evening"
    end
  end
end
