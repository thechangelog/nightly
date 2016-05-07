require_relative "../lib/repo"

RSpec.describe Repo do
  let(:repo) { Repo.new }

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
end
