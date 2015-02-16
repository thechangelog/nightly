require_relative "helpers"
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

DAY       = Date.parse(ENV["DATE"]) rescue Date.today
DIST_DIR  = "dist"
ISSUE_DIR = "#{DIST_DIR}/#{DAY.path}"
DATA_FILE = "#{ISSUE_DIR}/data.json"

desc "Launches local HTTP server on DIST_DIR"
task :preview do
  system "cd #{DIST_DIR} && python -m SimpleHTTPServer"
end

desc "Performs all operations for DAY except delivering the email"
task generate: [:sass, :images, "issue:template", :index]

task :dist do
  FileUtils.mkdir_p DIST_DIR
end

desc "Takes dat scss and makes it dat css"
task sass: [:dist] do
  system "sass nightly.scss #{DIST_DIR}/nightly.css"
end

desc "Copies the images directory to DIST_DIR"
task images: [:dist] do
  FileUtils.cp_r "images", "dist", preserve: false
end

desc "Processes the site's index w/ current linked list"
task index: [:dist] do
  template = ERB.new File.read "index.erb"

  File.write "#{DIST_DIR}/index.html", template.result(binding)
end

namespace :issue do
  task dir: [:dist] do
    FileUtils.mkdir_p ISSUE_DIR
  end

  desc "Generates DATA_FILE file for DAY. No-op if file exists"
  task data: [:dotenv, :dir] do
    if File.exist? DATA_FILE
      next
    end

    bq = BigQueryer.new DAY

    data = {
      top_new: bq.top_new,
      top_all: bq.top_all
    }

    File.write DATA_FILE, JSON.dump(data)
  end

  desc "Generates index.html file for DAY"
  task template: [:data] do
    template = ERB.new File.read "nightly.erb"

    data = Hashie::Mash.new JSON.parse File.read DATA_FILE

    top_new = data.top_new
    top_all = data.top_all

    File.write "#{ISSUE_DIR}/index.html", template.result(binding)
  end

  desc "Delivers DAY's email to Campaign Monitor"
  task deliver: [:dotenv] do
    auth = {api_key: ENV["CAMPAIGN_MONITOR_KEY"]}

    campaign_id = CreateSend::Campaign.create(
      auth,
      ENV["CAMPAIGN_MONITOR_ID"], # client id
      "Your Nightly Open Source Update – #{DAY}", # subject
      "Nightly – #{DAY}", # campaign name
      "The Changelog Nightly", # from name
      "nightly@changelog.com", # from email
      "editors@changelog.com", # reply to
      "http://nightly.thechangelog.com/#{DAY.path}", # html url
      nil, # text url
      [ENV["CAMPAIGN_MONITOR_LIST"]], # list ids
      [] # segment ids
    )

    CreateSend::Campaign.new(auth, campaign_id).send "editors@changelog.com"
  end
end
