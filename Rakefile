require "rubygems"
require "bundler/setup"
require "date"
require "open-uri"
require "json"
require "hashie/mash"
require "dotenv/tasks"
require "createsend"
require "pry"

require_relative "lib/core_ext/date"
require_relative "lib/core_ext/string"
require_relative "lib/bq_client"
require_relative "lib/template"

DATE      = Date.parse(ENV["DATE"]) rescue Date.today
DIST_DIR  = "dist"
ISSUE_DIR = "#{DIST_DIR}/#{DATE.path}"
ISSUE_URL = "http://nightly.thechangelog.com/#{DATE.path}"
DATA_FILE = "#{ISSUE_DIR}/data.json"

desc "Launches local HTTP server on DIST_DIR"
task :preview do
  system "cd #{DIST_DIR} && python -m SimpleHTTPServer"
end

desc "Performs all operations for DATE except delivering the email"
task generate: [:sass, :images, :issue, :index]

task :dist do
  FileUtils.mkdir_p DIST_DIR
end

desc "Takes dat scss and makes it dat css"
task sass: [:dist] do
  Dir["styles/*.scss"].each do |infile|
    outfile = File.basename(infile).gsub ".scss", ".css"
    next if outfile.start_with? "_"
    system "sass --sourcemap=none #{infile} #{DIST_DIR}/#{outfile}"
  end
end

desc "Copies the images directory to DIST_DIR"
task images: [:dist] do
  FileUtils.cp_r "images", "dist", preserve: false
  FileUtils.cp_r "#{Emoji.images_path}/emoji", "dist/images"
end

desc "Processes the site's index w/ current linked list"
task index: [:dist] do
  File.write "#{DIST_DIR}/index.html", Template.new("index").render
end

desc "Runs all tasks to generate DATE's issue"
task issue: ["issue:data", "issue:html"]

namespace :issue do
  task dir: [:dist] do
    FileUtils.mkdir_p ISSUE_DIR
  end

  desc "Generates DATA_FILE file for DATE. No-op if file exists"
  task data: [:dotenv, :dir] do
    if File.exist? DATA_FILE
      next
    end

    bq = BqClient.new DATE

    data = {
      top_new: bq.top_new,
      top_all: bq.top_all
    }

    File.write DATA_FILE, JSON.dump(data)
  end

  desc "Generates index.html file for DATE"
  task html: [:data] do
    template = Template.new "issue"

    data = Hashie::Mash.new JSON.parse File.read DATA_FILE

    File.write "#{ISSUE_DIR}/index.html", template.render({
      top_new: data.top_new,
      top_all: data.top_all,
      web_version: true
    })

    File.write "#{ISSUE_DIR}/email.html", template.render({
      top_new: data.top_new,
      top_all: data.top_all,
      web_version: false
    })
  end

  desc "Delivers DATE's email to Campaign Monitor"
  task deliver: [:dotenv] do
    auth = {api_key: ENV["CAMPAIGN_MONITOR_KEY"]}

    campaign_id = CreateSend::Campaign.create(
      auth,
      ENV["CAMPAIGN_MONITOR_ID"], # client id
      "The Hottest Repos on GitHub - #{DATE.day_month_abbrev}", # subject
      "Nightly – #{DATE.day_month_abbrev}", # campaign name
      "Changelog Nightly", # from name
      "nightly@changelog.com", # from email
      "editors@changelog.com", # reply to
      "#{ISSUE_URL}/email.html", # html url
      nil, # text url
      [ENV["CAMPAIGN_MONITOR_LIST"]], # list ids
      [] # segment ids
    )

    CreateSend::Campaign.new(auth, campaign_id).send "noreply@changelog.com" # send + confirmation email
  end
end
