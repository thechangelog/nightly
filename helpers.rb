class Issue
  def initialize file
    @file = file
    @parts = file.split "/"
  end

  def year;  @parts[0]; end
  def month; @parts[1]; end
  def day;   @parts[2]; end

  def valid?; File.directory?(@file) && !day.nil?; end
end

def issue_tree
  tree = {}

  issues = Dir["**/**"].map { |file| Issue.new file }.select(&:valid?)

  years = issues.map(&:year).uniq

  years.each do |year|
    tree[year] = {}

    year_issues = issues.select { |issue| issue.year == year }
    months = year_issues.map(&:month).uniq

    months.each do |month|
      month_issues = year_issues.select { |issue| issue.month == month }
      days = month_issues.map(&:day).uniq

      tree[year][month] = days
    end
  end

  tree
end

def development?
  ENV["NIGHTLY_ENV"] == "development"
end

def with_cache name, &block
  if !development?
    return block.call
  end

  cache_file = "#{name}.cache"

  if File.exists? cache_file
    File.open cache_file do |file|
      return Marshal.load file
    end
  else
    results = block.call

    File.open cache_file, "w" do |file|
      Marshal.dump results, file
    end

    results
  end
end
