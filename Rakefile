require "rubygems"
require "bundler/setup"
require "date"
require "json"
require "dotenv/tasks"
require "createsend"
require "pry"

require_relative "lib/core_ext/date"
require_relative "lib/core_ext/integer"
require_relative "lib/bq_client"
require_relative "lib/db"
require_relative "lib/issue"
require_relative "lib/repo"
require_relative "lib/template"
require_relative "lib/buffer"

DATE      = Date.parse(ENV["DATE"]) rescue Date.today
DIST_DIR  = "dist"
ISSUE_DIR = "#{DIST_DIR}/#{DATE.path}"
ISSUE_URL = "http://nightly.changelog.com/#{DATE.path}"
DATA_FILE = "#{ISSUE_DIR}/data.json"
THEMES    = %w(night day)

def each_issue &block
  Dir["#{DIST_DIR}/**/*/"].each do |path|
    if match = path.match(/(\d{4})\/(\d{2})\/(\d{2})/)
      y, m, d = match.captures.map(&:to_i)
      block.call path, Date.new(y, m, d)
    end
  end
end

desc "Launches local HTTP server on DIST_DIR"
task :preview do
  system("cd #{DIST_DIR} && python -m SimpleHTTPServer") ||
  system("cd #{DIST_DIR} && python3 -m http.server")
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
  system "gemoji extract dist/images/emoji"
end

desc "Processes the site's index w/ current linked list"
task index: [:dist] do
  File.write "#{DIST_DIR}/index.html", Template.new("html/index").render
end

desc "Runs all tasks to generate DATE's issue"
task issue: ["issue:data", "issue:html", "issue:text"]

desc "Runs all design-related tasks across all issues in DIST_DIR"
task redesign: [:sass, :images] do
  each_issue do |path, date|
    puts "Redesigning #{path}..."
    system "DATE=#{date} rake issue:html"
  end
end

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

    data[:top_all].each do |repo|
      DB.insert DATE, repo
    end

    File.write DATA_FILE, JSON.dump(data)
  end

  desc "Buffers issue's tweets for DATE"
  task buffer: [:data] do
    json = JSON.load File.read DATA_FILE
    issue = Issue.new DATE, json
    gotime = Buffer.new ENV["BUFFER_GO_TIME"], %w(Go), "#golang"
    jsparty = Buffer.new ENV["BUFFER_JS_PARTY"], %w(CSS JavaScript JSX PureScript TypeScript Vue)

    [gotime, jsparty].each do |buffer|
      buffer.injest issue.top_new
      buffer.injest issue.top_all_firsts
      buffer.queue
    end
  end

  desc "Generates index.html file for DATE"
  task html: [:data] do
    template = Template.new "html/issue"

    json = JSON.load File.read DATA_FILE
    issue = Issue.new DATE, json

    File.write "#{ISSUE_DIR}/index.html", template.render({
      issue: issue,
      web_version: true,
      theme: "night"
    })

    THEMES.each do |theme|
      File.write "#{ISSUE_DIR}/email-#{theme}.html", template.render({
        issue: issue,
        web_version: false,
        theme: theme
      })
    end
  end

  desc "Generates email.text file for DATE"
  task text: [:data] do
    template = Template.new "text/issue"

    json = JSON.load File.read DATA_FILE
    issue = Issue.new DATE, json

    File.write "#{ISSUE_DIR}/email.text", template.render({issue: issue})
  end

  desc "Delivers DATE's email to Campaign Monitor"
  task deliver: [:dotenv] do
    auth = {api_key: ENV["CAMPAIGN_MONITOR_KEY"]}

    CreateSend::List.new(auth, ENV["CAMPAIGN_MONITOR_LIST"]).segments.each do |segment|
      theme_name = segment.Title.downcase
      theme_id = segment.SegmentID

      next unless THEMES.include? theme_name

      campaign_id = CreateSend::Campaign.create(
        auth,
        ENV["CAMPAIGN_MONITOR_ID"], # client id
        "The Hottest Repos on GitHub - #{DATE.day_month_abbrev}", # subject
        "Nightly – #{DATE} (#{theme_name} theme)", # campaign name
        "Changelog Nightly", # from name
        "nightly@changelog.com", # from email
        "editors@changelog.com", # reply to
        "#{ISSUE_URL}/email-#{theme_name}.html", # html url
        nil, # text url
        [], # list ids
        [theme_id] # segment ids
      )

      CreateSend::Campaign.new(auth, campaign_id).send "noreply@changelog.com" # send + confirmation email
    end
  end
end

namespace :db do
  desc "Seed the database with historic data files"
  task seed: [:dotenv] do
    puts "Seeding the db..."

    each_issue do |path, date|
      data = JSON.load File.read File.expand_path("#{path}/data.json")
      data["top_all"].each do |json|
        repo = Repo.from_json json
        DB.insert date, repo
      end
    end

    puts "There are now #{DB.count} listings in the db."
  end
end
