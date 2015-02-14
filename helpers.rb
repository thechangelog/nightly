require "cgi"
require "json"

class BigQueryer
  attr_reader :bq, :day
  def initialize day
    @day = day
    @bq = BigQuery::Client.new({
      "client_id"     => ENV["BQ_CLIENT_ID"],
      "service_email" => ENV["BQ_SERVICE_EMAIL"],
      "key"           => ENV["BQ_KEY"],
      "project_id"    => ENV["BQ_PROJECT_ID"]
    })
  end

  def top_all
    response_to_repo_list bq.query(top_all_sql)
  end

  def top_new
    response_to_repo_list bq.query(top_new_sql)
  end

  private

  def response_to_repo_list query_result
    # each `row` hash has this format:
    # {"f"=>[{"v"=>"https://...snip..."}, {"v"=>"45"}]}
    query_result["rows"].map { |row|
      {
        url: row["f"].first["v"],
        count: row["f"].last["v"].to_i
      }
    }
    .map { |row|
      repo = JSON.load open("#{row[:url]}?access_token=#{ENV['GITHUB_TOKEN']}")
      repo["new_stargazers_count"] = row[:count]
      repo["description"] = CGI.escapeHTML(repo["description"] || "")
      repo
    }
  end

  def top_all_sql
    <<-SQL
    SELECT repo.url, COUNT(repo.name) as count FROM
    TABLE_DATE_RANGE(githubarchive:day.events_,
      TIMESTAMP("#{day}"),
      TIMESTAMP("#{day}")
    )
    WHERE type="WatchEvent"
    GROUP BY repo.id, repo.name, repo.url
    HAVING count >= 10
    ORDER BY count DESC
    LIMIT 25
    SQL
  end

  def top_new_sql
    <<-SQL
    SELECT repo.url, COUNT(repo.name) as count FROM
    TABLE_DATE_RANGE(githubarchive:day.events_,
      TIMESTAMP("#{day}"),
      TIMESTAMP("#{day}")
    )
    WHERE type="WatchEvent"
    AND repo.url in (
      SELECT repo.url FROM (
        SELECT repo.url,
          JSON_EXTRACT(payload, '$.ref_type') as ref_type,
        FROM (TABLE_DATE_RANGE(githubarchive:day.events_,
          TIMESTAMP("#{day}"),
          TIMESTAMP("#{day}")
        ))
        WHERE type="CreateEvent"
      )
      WHERE ref_type='"repository"'
    )
    GROUP BY repo.id, repo.name, repo.url
    HAVING count >= 5
    ORDER BY count DESC
    LIMIT 25
    SQL
  end
end

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

def development?
  ENV["NIGHTLY_ENV"] == "development"
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
