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
    it "is true when repo name matches a malware word" do
      repo.name = "Rawaha404/PUBG-HACK-SPOOFER-DOWNLOAD-2022-UNDETECTED"
      expect(repo).to be_malware
    end

    it "is false when repo description matches a malware word" do
      repo.description = "this is such a hack sorry"
      expect(repo).to_not be_malware
    end
  end

  describe "#no_description?" do
    it "is true when description is nil, empty, or blank" do
      [nil, "", "   "].each do |bad|
        repo.description = bad
        expect(repo.no_description?).to be true
      end
    end

    it "is false when descripton has contents" do
      repo.description = "ohai"
      expect(repo.no_description?).to be false
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
