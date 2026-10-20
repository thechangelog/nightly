require "date"
require_relative "../lib/new_repos"

RSpec.describe NewRepos do
  let(:day) { Date.new 2026, 10, 19 }
  let(:github) { double "github" }
  let(:new_repos) { NewRepos.new day, github }

  def item name, attrs={}
    {
      "id" => name.hash.abs,
      "name" => name,
      "full_name" => "someone/#{name}",
      "url" => "https://api.github.com/repos/someone/#{name}",
      "html_url" => "https://github.com/someone/#{name}",
      "description" => "A perfectly fine project",
      "stargazers_count" => 100,
      "size" => 5000,
      "language" => "Ruby",
      "topics" => [],
      "owner" => {"id" => 1, "login" => "someone"}
    }.merge(attrs)
  end

  def search_returns *items
    allow(github).to receive(:search_repositories).and_return items
  end

  def by owner, attrs={}
    {"owner" => {"id" => owner.hash.abs, "login" => owner}}.merge(attrs)
  end

  def days_ago days
    (Time.now - days * 86_400).utc.iso8601
  end

  def account attrs={}
    {"followers" => 50, "public_repos" => 40, "created_at" => days_ago(3 * 365)}.merge(attrs)
  end

  let(:accounts) { {} }

  before do
    allow($stderr).to receive(:puts) # skip lines are asserted in examples below
    allow(github).to receive(:user) { |login| accounts.fetch(login) { account } }
  end

  describe "#top" do
    it "searches for repos created that day with at least ten stars" do
      expect(github).to receive(:search_repositories).with("created:2026-10-19 stars:>=10", 3).and_return []
      expect(new_repos.top).to eq []
    end

    it "keeps the order stars gave them, up to the limit" do
      search_returns item("a", "stargazers_count" => 90), item("b", "stargazers_count" => 80), item("c")
      expect(new_repos.top(2).map(&:name)).to eq %w(a b)
    end

    it "counts all of a new repo's stars as new stars" do
      search_returns item("a", "stargazers_count" => 42)
      repo = new_repos.top.first

      expect(repo.new_stargazers_count).to eq 42
      expect(repo).not_to be_too_many_new_stars
    end

    it "escapes descriptions for the email" do
      search_returns item("a", "description" => "Use <script> & more")
      expect(new_repos.top.first.description).to eq "Use &lt;script&gt; &amp; more"
    end

    it "skips repos the shared checks reject, and says why" do
      search_returns item("tiny", "description" => "x"), item("fine")

      expect(new_repos.top.map(&:name)).to eq %w(fine)
      expect { new_repos.top }.to output(
        %r{skipped https://github.com/someone/tiny \(100 stars\): description too short}
      ).to_stderr
    end

    it "skips repos whose owner or name is on the malware list" do
      search_returns item("tool", "url" => "https://api.github.com/repos/free-cheats/tool"), item("fine")
      expect(new_repos.top.map(&:name)).to eq %w(fine)
    end

    it "copes with a day that has nothing" do
      search_returns
      expect(new_repos.top).to eq []
    end

    describe "lookalike repos" do
      def batch size, stars, kb
        Array.new(size) { |i| item("spam#{stars}-#{i}", by("farm#{i}", "stargazers_count" => stars, "size" => kb + i % 2)) }
      end

      it "drops a group that shares a star count and a size" do
        search_returns(*batch(4, 20, 12), item("real", "stargazers_count" => 15))

        expect(new_repos.top.map(&:name)).to eq %w(real)
        expect { new_repos.top }.to output(/one of 4 lookalike repos/).to_stderr
      end

      it "keeps a smaller coincidence" do
        search_returns(*batch(3, 20, 12))
        expect(new_repos.top.length).to eq 3
      end

      it "keeps repos that share stars but not size" do
        search_returns(*Array.new(5) { |i| item("r#{i}", "stargazers_count" => 20, "size" => 1000 * (i + 1)) })
        expect(new_repos.top.length).to eq 5
      end
    end

    describe "accounts" do
      it "drops repos from a brand new account nobody follows" do
        accounts["newbie"] = account "followers" => 0, "created_at" => days_ago(5)
        search_returns item("a", by("newbie")), item("b", by("veteran"))

        expect(new_repos.top.map(&:name)).to eq %w(b)
        expect { new_repos.top }.to output(/skipped \S+a \(100 stars\): throwaway account/).to_stderr
      end

      it "drops a tiny repo from an account with a few repos and no followers" do
        accounts["lurker"] = account "followers" => 0, "public_repos" => 2, "created_at" => days_ago(400)
        search_returns item("tiny", by("lurker", "size" => 10)), item("big", by("lurker", "size" => 5000))

        expect(new_repos.top.map(&:name)).to eq %w(big)
      end

      it "drops suspicious topics from an account that hasn't established itself" do
        accounts["fresh"] = account "followers" => 1, "created_at" => days_ago(100)
        search_returns item("guide", by("fresh", "topics" => %w(scholarship free-tuition))), item("ok", by("fresh"))

        expect(new_repos.top.map(&:name)).to eq %w(ok)
        expect { new_repos.top }.to output(/suspicious topics/).to_stderr
      end

      it "gives an established account's suspicious topics a pass" do
        search_returns item("skills", by("veteran", "topics" => %w(blender roblox)))
        expect(new_repos.top.map(&:name)).to eq %w(skills)
      end

      it "looks each owner up once" do
        search_returns item("a", by("pair")), item("b", by("pair"))

        expect(new_repos.top.length).to eq 2
        expect(github).to have_received(:user).once
      end

      it "stops looking owners up once it has enough" do
        search_returns(*(1..6).map { |i| item("r#{i}", by("o#{i}", "stargazers_count" => 100 - i)) })

        expect(new_repos.top(2).map(&:name)).to eq %w(r1 r2)
        expect(github).to have_received(:user).twice
      end

      it "caps the owner lookups" do
        search_returns(*(1..6).map { |i| item("r#{i}", by("o#{i}", "stargazers_count" => 100 - i)) })

        expect(new_repos.top(15, 3).length).to eq 3
        expect(github).to have_received(:user).exactly(3).times
      end

      it "does not look up the owner of a repo the other checks already rejected" do
        search_returns item("tiny", by("nobody", "description" => "x"))

        expect(new_repos.top).to eq []
        expect(github).not_to have_received(:user)
      end

      it "skips a repo whose owner can't be fetched, and says why" do
        allow(github).to receive(:user).with("ghost").and_raise("404 Not Found")
        search_returns item("a", by("ghost")), item("b", by("veteran"))

        expect(new_repos.top.map(&:name)).to eq %w(b)
        expect { new_repos.top }.to output(/skipped \S+a \(100 stars\): RuntimeError: 404 Not Found/).to_stderr
      end
    end
  end
end
