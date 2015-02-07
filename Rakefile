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

DIST_DIR = "dist"

desc "purges caches and generated files"
task :clean do
  system "rm -rf #{DIST_DIR} *.cache"
end

desc "launches local HTTP server"
task :preview do
  system "cd #{DIST_DIR} && python -m SimpleHTTPServer"
end

task generate: [:sass, :issue, :index]

task :dist do
  FileUtils.mkdir_p DIST_DIR
end

desc "Takes dat scss and makes it dat css"
task sass: [:dist] do
  system "sass nightly.scss #{DIST_DIR}/nightly.css"
end

desc "Processes the site's index w/ current linked list"
task index: [:dist] do
  template = ERB.new IO.read "index.erb"

  FileUtils.cd DIST_DIR

  File.open "index.html", "w" do |file|
    file.print template.result(binding)
  end
end

desc "Processes new issue w/ data from ENV['DATE'] or today"
task issue: [:dotenv, :dist] do
  day = Date.parse(ENV["DATE"]) rescue Date.today
  year = day.year
  month = day.strftime "%m"
  day = day.strftime "%d"

  bq = BigQuery::Client.new({
    "client_id"     => ENV["BQ_CLIENT_ID"],
    "service_email" => ENV["BQ_SERVICE_EMAIL"],
    "key"           => ENV["BQ_KEY"],
    "project_id"    => ENV["BQ_PROJECT_ID"]
  })

  top_watched_sql = <<-SQL
  SELECT repo.url, COUNT(repo.name) as cnt FROM
  TABLE_DATE_RANGE(githubarchive:day.events_,
    TIMESTAMP("#{day}"),
    TIMESTAMP("#{day}")
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

  nightly_path = "#{DIST_DIR}/#{year}/#{month}/#{day}"

  FileUtils.mkdir_p nightly_path

  File.open "#{nightly_path}/index.html", "w" do |file|
    file.print template.result(binding)
  end
end
