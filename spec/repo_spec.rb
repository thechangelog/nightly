require_relative "../lib/repo"

RSpec.describe Repo do
  let(:repo) { Repo.new owner: {} }

  describe "#blocked?" do
    it "is true when repo id is blocked" do
      repo.id = repo.send(:blocked_github_repo_ids).sample
      expect(repo).to be_blocked
    end

    it "is true when repo owner id is in the blocked" do
      repo.owner.id = repo.send(:blocked_github_user_ids).sample
      expect(repo).to be_blocked
    end

    it "is false when repo id is not in the blocked" do
      expect(repo).not_to be_blocked
    end
  end

  describe ".from_api" do
    it "records the stars gained and escapes the description" do
      repo = Repo.from_api({"description" => "<b>hi</b>", "stargazers_count" => 9}, 4)

      expect(repo.new_stargazers_count).to eq 4
      expect(repo.description).to eq "&lt;b&gt;hi&lt;/b&gt;"
    end

    it "copes with a missing description" do
      expect(Repo.from_api({}, 1).description).to eq ""
    end
  end

  describe "#classy_description" do
    it "does nothing if the description is already classy" do
      original = "<img src='/images/emoji/unicode/26a1.png'/> Lodash inspired JSDoc 3 template / theme"
      repo.description = original
      expect(repo.classy_description).to eq original
    end

    it "adds emojis and links where appropriate" do
      repo.description = ":shipit: to http://example.com"
      expect(repo.classy_description).to eq "<img alt='shipit' src='/images/emoji/shipit.png' style='vertical-align:middle' width='20' height='20' /> to <a href='http://example.com'>http://example.com</a>"
    end
  end

  describe "#description_too_short?" do
    it "is true when description is nil, empty, or blank" do
      [nil, "", "   "].each do |bad|
        repo.description = bad
        expect(repo.description_too_short?).to be true
      end
    end

    it "is true when description has short contents" do
      repo.description = "ohai"
      expect(repo.description_too_short?).to be true
    end

    it "is true when description is less than 3 words" do
        repo.description = "too shot"
        expect(repo.description_too_short?).to be true
    end

    it "is false when descripton has long contents" do
      repo.description = "ohai this is a real one"
      expect(repo.description_too_short?).to be false
    end
  end

  describe "#description_too_long?" do
    it "is true when longer than a tweet" do
      repo.description = "0" * 281
      expect(repo.description_too_long?).to be true
    end

    it "is false when tweet-sized" do
      repo.description = "0" * 280
      expect(repo.description_too_long?).to be false
    end
  end

  describe "#english?" do
    it "is true when description is in English" do
      repo.description = "Quake III Arena GPL Source Release"
      expect(repo).to be_english
      repo.description = "Go library to trace Linux syscalls using the FTRACE kernel framework."
      expect(repo).to be_english
    end

    it "is false when description is Swedish" do
      repo.description = "Jargon.ist - Bilgisayar bilimleri jargonu sözlüğü"
      expect(repo).not_to be_english
    end

    it "is false when description is Chinese" do
      repo.description = "技术面试需要掌握的基础知识整理，欢迎编辑~"
      expect(repo).not_to be_english
    end
  end

  describe "#language_class" do
    it "downcases" do
      repo.language = "JavaScript"
      expect(repo.language_class).to eq "javascript"
    end

    it "converts spaces to hypens" do
      repo.language = "Objective C"
      expect(repo.language_class).to eq "objective-c"
    end

    it "handles the C# special case" do
      repo.language = "c#"
      expect(repo.language_class).to eq "csharp"
    end
  end

  describe "#malware?" do
    it "is true when name and description are identical" do
      repo.name = "MyProject91262"
      repo.description = "MyProject91262"
      expect(repo).to be_malware
    end

    it "is true when name and description are near matches" do
      [
        ["MyProject91262", "MyPorject91262"],
        ["-Projectus2", "Projectus2"]
      ].each do |tuple|
        repo.name = tuple[0]
        repo.description = tuple[1]
        expect(repo).to be_malware
      end
    end

    it "is false when name and description are not near matches" do
      repo.name = "MyProject91262"
      repo.description = "Your Project is the cool one"
      expect(repo).not_to be_malware
    end
  end

  describe "#obscene?" do
    before do
      repo.owner = double login: ""
    end

    it "is true when description has an obscenity in it" do
      repo.description = "This is great, AssFace"
      expect(repo).to be_obscene
    end

    it "is true when the owner login has an obscenity in it" do
      repo.owner = double login: "NiggerFoundation"
      expect(repo).to be_obscene
    end

    it "is true when the name as an obscenity in it" do
      repo.name = "Apparently poopstain is an obscenity..."
      expect(repo).to be_obscene
    end

    it "is true when owner has one of our added obscenities in it" do
      repo.owner = double login: "techGay/91porn"
      expect(repo).to be_obscene
    end

    it "is false when none of those things have obscenities in them" do
      repo.name = "proximityhash"
      repo.description = "Geohashes in proximity"
      expect(repo).not_to be_obscene
    end

    it "is false when a short entry is only part of an everyday word" do
      [
        "Python tools for AI assistants",
        "Agent skills for document analytics",
        "A shell for the Hello World class",
        "Title page standard"
      ].each do |text|
        repo.description = text
        expect(repo).not_to be_obscene, "expected #{text.inspect} to be fine"
      end
    end

    it "is true when a short entry stands alone as a word" do
      ["porn viewer", "the-porn-app", "my_porn_site", "91porn", "techGay"].each do |text|
        repo.description = text
        expect(repo).to be_obscene, "expected #{text.inspect} to be obscene"
      end
    end

    it "is true when a long entry is part of a compound" do
      repo.name = "poopstainTracker"
      expect(repo).to be_obscene
    end

    it "does not choke on a missing name" do
      repo.name = nil
      repo.description = "Geohashes in proximity"
      expect(repo).not_to be_obscene
    end
  end

  describe "account checks" do
    let(:now) { Time.utc 2026, 10, 20 }
    let(:repo) { Repo.new name: "widget", size: 5000, topics: [] }

    def account attrs={}
      Hashie::Mash.new({followers: 50, public_repos: 40, created_at: "2015-01-01T00:00:00Z"}.merge(attrs))
    end

    describe "#throwaway_account?" do
      it "is true for a new account nobody follows" do
        expect(repo.throwaway_account?(account(followers: 0, created_at: "2026-10-01T00:00:00Z"), now)).to be true
      end

      it "is true for a few repos, no followers, and almost nothing in this one" do
        repo.size = 10
        expect(repo.throwaway_account?(account(followers: 0, public_repos: 3), now)).to be true
      end

      it "is false when this repo has real content" do
        expect(repo.throwaway_account?(account(followers: 0, public_repos: 3), now)).to be false
      end

      it "is false when somebody follows the account" do
        expect(repo.throwaway_account?(account(followers: 1, created_at: "2026-10-19T00:00:00Z"), now)).to be false
      end

      it "is false for an old account with many repos" do
        expect(repo.throwaway_account?(account(followers: 0), now)).to be false
      end

      it "does not judge an account whose age is unknown" do
        expect(repo.throwaway_account?(account(followers: 0, created_at: nil), now)).to be false
      end
    end

    describe "#established_account?" do
      it "is true with five followers" do
        expect(repo.established_account?(account(followers: 5, created_at: "2026-10-19T00:00:00Z"), now)).to be true
      end

      it "is true after a year even with no followers" do
        expect(repo.established_account?(account(followers: 0, created_at: "2025-10-01T00:00:00Z"), now)).to be true
      end

      it "is false when both are short" do
        expect(repo.established_account?(account(followers: 4, created_at: "2026-01-01T00:00:00Z"), now)).to be false
      end
    end

    describe "#suspicious_topics?" do
      it "is true when a topic is on the malware list" do
        repo.topics = %w(scholarship free-tuition)
        expect(repo).to be_suspicious_topics
      end

      it "is false otherwise, or with no topics" do
        repo.topics = %w(ruby cli)
        expect(repo).not_to be_suspicious_topics
        expect(Repo.new).not_to be_suspicious_topics
      end
    end

    describe "#account_rejection_reason" do
      it "prefers the throwaway reason" do
        repo.topics = %w(free-tuition)
        reason = repo.account_rejection_reason account(followers: 0, created_at: "2026-10-19T00:00:00Z"), now
        expect(reason).to eq "throwaway account"
      end

      it "flags suspicious topics only on accounts that are not established" do
        repo.topics = %w(free-tuition)
        expect(repo.account_rejection_reason(account(followers: 2, created_at: "2026-02-01T00:00:00Z"), now)).to eq "suspicious topics"
        expect(repo.account_rejection_reason(account, now)).to be_nil
      end

      it "is nil for a clean repo from a clean account" do
        expect(repo.account_rejection_reason(account, now)).to be_nil
      end
    end
  end

  describe "#rejection_reason" do
    def build_repo changes={}
      Repo.new({
        id: 1, name: "widget", description: "A perfectly fine project",
        owner: {id: 2, login: "someone"}, stargazers_count: 10, new_stargazers_count: 10
      }.merge(changes))
    end

    it "is nil when nothing is wrong" do
      expect(build_repo.rejection_reason).to be_nil
    end

    it "names the check that failed" do
      {
        "blocked" => {id: 156648725},
        "malware" => {description: "A free cheat for your game"},
        "description too short" => {description: "Tiny"},
        "description too long" => {description: "word " * 60},
        "obscene" => {description: "A fine porn viewer"},
        "too many new stars" => {new_stargazers_count: 11}
      }.each do |reason, changes|
        expect(build_repo(changes).rejection_reason).to eq(reason), "expected #{changes} to be #{reason}"
      end
    end

    it "reports the first failing check" do
      repo = build_repo id: 156648725, description: "A free cheat for your game"
      expect(repo.rejection_reason).to eq "blocked"
    end
  end

  describe "#too_many_new_stars?" do
    it "is true when repo has more new stars than total stars" do
      repo.new_stargazers_count = 15
      repo.stargazers_count = 12
      expect(repo).to be_too_many_new_stars
    end

    it "is false when repo has same new stars and total stars" do
      repo.new_stargazers_count = 1500
      repo.stargazers_count = 1500
      expect(repo).not_to be_too_many_new_stars
    end

    it "is false when repo has more total stars than new stars" do
      repo.new_stargazers_count = 1500
      repo.stargazers_count = 1501
      expect(repo).not_to be_too_many_new_stars
    end
  end
end
