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

  def path
    "#{classy_year}/#{classy_month}/#{classy_day}"
  end
end
