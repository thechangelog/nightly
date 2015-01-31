require_relative "helpers"
require "date"
require "open-uri"
require "json"
require "erb"
require "rubygems"
require "bundler/setup"
require "big_query"
require "hashie/mash"
require "pry"
require "dotenv/tasks"

desc "purges caches and generated files"
task :clean do
  system "rm -rf index.html *.cache"
end

desc "launches local HTTP server"
task :preview do
  system "python -m SimpleHTTPServer"
end

desc "generates a new index.html w/ current data (uses cache in dev)"
task generate: :dotenv do
  today = Date.today.to_s
  bq = BigQuery::Client.new({
    "client_id"     => ENV["BQ_CLIENT_ID"],
    "service_email" => ENV["BQ_SERVICE_EMAIL"],
    "key"           => ENV["BQ_KEY"],
    "project_id"    => ENV["BQ_PROJECT_ID"]
  })

  top_watched_sql = <<-SQL
  SELECT repo.url, COUNT(repo.name) as cnt FROM
  TABLE_DATE_RANGE(githubarchive:day.events_,
    TIMESTAMP("#{today}"),
    TIMESTAMP("#{today}")
  )
  WHERE type="WatchEvent"
  GROUP BY repo.id, repo.name, repo.url
  HAVING cnt >= 10
  ORDER BY cnt DESC
  LIMIT 25
  SQL

  top_new_sql = <<-SQL
  SELECT repo.url, COUNT(repo.name) as cnt FROM
  TABLE_DATE_RANGE(githubarchive:day.events_,
    TIMESTAMP("#{today}"),
    TIMESTAMP("#{today}")
  )
  WHERE type="WatchEvent"
  AND repo.url in (
    SELECT repo.url FROM (
      SELECT repo.url,
        JSON_EXTRACT(payload, '$.ref_type') as ref_type,
      FROM (TABLE_DATE_RANGE(githubarchive:day.events_,
        TIMESTAMP("2015-01-19"),
        TIMESTAMP("2015-01-19")
      ))
      WHERE type="CreateEvent"
    )
    WHERE ref_type='"repository"'
  )
  GROUP BY repo.id, repo.name, repo.url
  HAVING cnt >= 5
  ORDER BY cnt DESC
  LIMIT 25
  SQL

  top_new = with_cache "top_new" do
    urls = bq.query(top_new_sql)["rows"].map { |row| row["f"].first["v"] }
    urls.map { |url| Hashie::Mash.new JSON.load(open(url)) }
  end

  top_watched = with_cache "top_watched" do
    urls = bq.query(top_watched_sql)["rows"].map { |row| row["f"].first["v"] }
    urls.map { |url| Hashie::Mash.new JSON.load(open(url)) }
  end

  template = ERB.new IO.read "nightly.erb"

  File.open "index.html", "w" do |file|
    file.print template.result(binding)
  end
end
