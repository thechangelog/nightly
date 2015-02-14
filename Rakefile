require_relative "helpers"
require "cgi"
require "date"
require "open-uri"
require "json"
require "erb"
require "rubygems"
require "bundler/setup"
require "big_query"
require "hashie/mash"
require "dotenv/tasks"
require "createsend"
require "pry"

DIST_DIR = "dist"
DAY = Date.parse(ENV["DATE"]) rescue Date.today
ISSUE_DIR = "#{DIST_DIR}/#{DAY.path}"

desc "launches local HTTP server"
task :preview do
  system "cd #{DIST_DIR} && python -m SimpleHTTPServer"
end

task generate: [:sass, :issue_template, :index]

task :dist do
  FileUtils.mkdir_p DIST_DIR
end

task issue_dir: [:dist] do
  FileUtils.mkdir_p ISSUE_DIR
end

desc "Takes dat scss and makes it dat css"
task sass: [:dist] do
  system "sass nightly.scss #{DIST_DIR}/nightly.css"
end

desc "Processes the site's index w/ current linked list"
task index: [:dist] do
  template = ERB.new IO.read "index.erb"

  File.open "#{DIST_DIR}/index.html", "w" do |file|
    file.print template.result(binding)
  end
end

desc "Generates data.json file for ENV['DAY']. No-op if file exists"
task issue_data: [:dotenv, :issue_dir] do
  data_file = "#{ISSUE_DIR}/data.json"

  if File.exist? data_file
    next
  end

  bq = BigQuery::Client.new({
    "client_id"     => ENV["BQ_CLIENT_ID"],
    "service_email" => ENV["BQ_SERVICE_EMAIL"],
    "key"           => ENV["BQ_KEY"],
    "project_id"    => ENV["BQ_PROJECT_ID"]
  })

  top_all_sql = <<-SQL
  SELECT repo.url, COUNT(repo.name) as count FROM
  TABLE_DATE_RANGE(githubarchive:day.events_,
    TIMESTAMP("#{DAY}"),
    TIMESTAMP("#{DAY}")
  )
  WHERE type="WatchEvent"
  GROUP BY repo.id, repo.name, repo.url
  HAVING count >= 10
  ORDER BY count DESC
  LIMIT 25
  SQL

  top_new_sql = <<-SQL
  SELECT repo.url, COUNT(repo.name) as count FROM
  TABLE_DATE_RANGE(githubarchive:day.events_,
    TIMESTAMP("#{DAY}"),
    TIMESTAMP("#{DAY}")
  )
  WHERE type="WatchEvent"
  AND repo.url in (
    SELECT repo.url FROM (
      SELECT repo.url,
        JSON_EXTRACT(payload, '$.ref_type') as ref_type,
      FROM (TABLE_DATE_RANGE(githubarchive:day.events_,
        TIMESTAMP("#{DAY}"),
        TIMESTAMP("#{DAY}")
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

  data = {}

  data["top_new"] = bq.query(top_new_sql)["rows"].map { |row|
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

  data["top_all"] = bq.query(top_all_sql)["rows"].map { |row|
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

  File.open data_file, "w" do |file|
    file.print JSON.dump data
  end
end

desc "Generates index.html file for ENV['DAY']"
task issue_template: [:issue_data] do
  template = ERB.new IO.read "nightly.erb"

  data = Hashie::Mash.new JSON.parse File.read "#{ISSUE_DIR}/data.json"

  top_new = data.top_new
  top_all = data.top_all

  File.open "#{DIST_DIR}/#{DAY.path}/index.html", "w" do |file|
    file.print template.result(binding)
  end
end

desc "Sends today's email to Campaign Monitor"
task email: [:dotenv] do
  CreateSend::Campaign.create(
    {api_key: ENV["CAMPAIGN_MONITOR_KEY"]}, # auth
    ENV["CAMPAIGN_MONITOR_ID"], # client id
    "Your Nightly Open Source Update – #{DAY}", # subject
    "Nightly – #{DAY}", # campaign name
    "The Changelog Nightly", # from name
    "nightly@changelog.com", # from email
    "editors@changelog.com", # reply to
    "http://nightly.thechangelog.com/#{DAY.path}", # html url
    nil, # text url
    ["92703E980C88E895"], # list ids
    [] # segment ids
  )
end
