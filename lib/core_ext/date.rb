class Date
  def classy_year
    strftime "%Y"
  end

  def classy_month
    strftime "%m"
  end

  def classy_day
    strftime "%d"
  end

  def day_month_abbrev
    strftime "%b %d"
  end

  def day_month_year
    strftime "%B %d, %Y"
  end

  def path
    "#{classy_year}/#{classy_month}/#{classy_day}"
  end
end
