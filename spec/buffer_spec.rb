require_relative "../lib/buffer"

RSpec.describe Buffer do
  let(:buffer) { Buffer.new "8675309", ["Go", "CSS"] }
  let(:repo1) { double language: "JavaScript", english?: true }
  let(:repo2) { double language: "Go", english?: true }
  let(:repo3) { double language: "CSS", english?: true }
  let(:repo4) { double language: "Go", english?: false }

  it "takes an optional tags string" do
    tagged = Buffer.new "8675309", ["Go"], "#golang #ohmy"
    expect(tagged.tags).to eq "#golang #ohmy"
  end

  describe "#injest" do
    it "takes a single repo" do
      buffer.injest repo2
      expect(buffer.repos).to eq [repo2]
    end

    it "takes a list of repos" do
      buffer.injest [repo2, repo3]
      expect(buffer.repos).to eq [repo2, repo3]
    end

    it "rejects repos that don't have matching language" do
      buffer.injest [repo1, repo2, repo3]
      expect(buffer.repos).to eq [repo2, repo3]
    end

    it "rejects non-English repos" do
      buffer.injest [repo2, repo3, repo4]
      expect(buffer.repos).to eq [repo2, repo3]
    end

    it "rejects dupes" do
      buffer.injest [repo2, repo2]
      expect(buffer.repos).to eq [repo2]
    end
  end
end
