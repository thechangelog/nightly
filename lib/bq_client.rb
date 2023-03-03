require "json"
require "big_query"

class BqClient
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

  def top_all limit=50
    response_to_repo_list bq.query(top_all_sql), limit
  end

  def top_new limit=50
    response_to_repo_list bq.query(top_new_sql), limit
  end

  private

  def response_to_repo_list query_result, limit
    query_result["rows"]
      .map(&:extract_fields_from_row)
      # run this check before hitting the GH API to avoid rate limits
      .reject { |row| row[:url].malware? }
      # set a max repo limit before hitting the GH API to avoid rate limits
      .first(limit)
      .map { |row|
        begin
          repo = Repo.from_github row[:url], row[:count]
          next if repo.blocked?
          next if repo.no_description?
          next if repo.description_too_long?
          next if repo.obscene?
          next if repo.too_many_new_stars?
          repo
        rescue
          next
        end
      }.compact
  end

  # each `row` hash has this format:
  # {"f"=>[{"v"=>"https://...snip..."}, {"v"=>"45"}]}
  def extract_fields_from_row row
    {
      url: row["f"].first["v"],
      count: row["f"].last["v"].to_i
    }
  end

  def top_all_sql
    <<-SQL
    SELECT repo.url, COUNT(repo.name) as count FROM
    TABLE_DATE_RANGE([githubarchive:day.],
      TIMESTAMP("#{day}"),
      TIMESTAMP("#{day}")
    )
    WHERE type="WatchEvent"
    GROUP BY repo.id, repo.name, repo.url
    HAVING count >= 50
    ORDER BY count DESC
    LIMIT 1000
    SQL
  end

  def top_new_sql
    <<-SQL
    SELECT repo.url, COUNT(repo.name) AS count FROM
    TABLE_DATE_RANGE([githubarchive:day.],
      TIMESTAMP("#{day}"),
      TIMESTAMP("#{day}")
    )
    WHERE type="WatchEvent"
    AND repo.url IN (
      SELECT repo.url FROM (
        SELECT repo.url,
          JSON_EXTRACT(payload, '$.ref_type') AS ref_type,
        FROM (TABLE_DATE_RANGE([githubarchive:day.],
          TIMESTAMP("#{day}"),
          TIMESTAMP("#{day}")
        ))
        WHERE type IN ("CreateEvent", "PublicEvent")
      )
      WHERE ref_type='"repository"' OR ref_type IS NULL # PublicEvent has no ref_type
    )
    GROUP BY repo.id, repo.name, repo.url
    HAVING count >= 25
    ORDER BY count DESC
    LIMIT 1000
    SQL
  end
end
