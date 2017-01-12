require_relative "../lib/repo"

RSpec.describe Repo do
  let(:repo) { Repo.new }

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

  describe "#language_param" do
    it "returns the repo's language" do
      repo.language = "ruby"
      expect(repo.language_param).to eq "ruby"
    end

    it "handles the C# special case" do
      repo.language = "c#"
      expect(repo.language_param).to eq "csharp"
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
end
