require "date"
require_relative "../lib/bq_client"

RSpec.describe BqClient do
  let(:day) { Date.new 2026, 10, 19 }
  let(:bq) { double "bq" }
  let(:client) { BqClient.new day, bq }
  let(:repos) { {} }

  def row url, count
    {"f" => [{"v" => url}, {"v" => count.to_s}]}
  end

  def result *rows
    {"rows" => rows}
  end

  def good_repo name, attrs={}
    Repo.new({
      id: name.hash.abs,
      name: name,
      description: "A perfectly fine project",
      stargazers_count: 100,
      new_stargazers_count: 60,
      owner: {id: 1, login: "someone"}
    }.merge(attrs))
  end

  def url_for name
    "https://api.github.com/repos/someone/#{name}"
  end

  before do
    allow($stderr).to receive(:puts) # skip lines are asserted in one example below
    allow(Repo).to receive(:from_github) { |url, _| repos.fetch(url) { raise "404 Not Found" } }
  end

  describe "#top_all" do
    it "returns the first repos that pass, in order" do
      %w(a b c).each { |name| repos[url_for(name)] = good_repo(name) }
      allow(bq).to receive(:query).and_return result(*%w(a b c).map { |n| row url_for(n), 90 })

      expect(client.top_all(2).map(&:name)).to eq %w(a b)
    end

    it "keeps looking past repos that were rejected" do
      repos[url_for("gone1")] = good_repo("gone1", description: "x")
      repos[url_for("gone2")] = good_repo("gone2", stargazers_count: 10, new_stargazers_count: 50)
      %w(a b c).each { |name| repos[url_for(name)] = good_repo(name) }
      names = %w(gone1 gone2 missing a b c)
      allow(bq).to receive(:query).and_return result(*names.map { |n| row url_for(n), 90 })

      expect(client.top_all(3).map(&:name)).to eq %w(a b c)
    end

    it "stops after max_lookups GitHub calls" do
      names = (1..10).map { |i| "r#{i}" }
      names.each { |name| repos[url_for(name)] = good_repo(name) }
      allow(bq).to receive(:query).and_return result(*names.map { |n| row url_for(n), 90 })

      expect(client.top_all(10, 4).map(&:name)).to eq %w(r1 r2 r3 r4)
      expect(Repo).to have_received(:from_github).exactly(4).times
    end

    it "skips malware urls without spending a GitHub call" do
      allow(bq).to receive(:query).and_return result(row(url_for("free-cheat-engine"), 90))

      expect(client.top_all).to eq []
      expect(Repo).not_to have_received(:from_github)
    end

    it "says why each repo was skipped" do
      repos[url_for("bad")] = good_repo("bad", description: "x")
      allow(bq).to receive(:query).and_return result(row(url_for("bad"), 90), row(url_for("missing"), 70))

      expect { client.top_all }.to output(
        /skipped \S+bad \(90 stars\): description too short.*skipped \S+missing \(70 stars\): RuntimeError: 404 Not Found/m
      ).to_stderr
    end

    it "copes with a query that returns no rows" do
      allow(bq).to receive(:query).and_return({})
      expect(client.top_all).to eq []
    end
  end
end
