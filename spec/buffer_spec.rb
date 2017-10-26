require_relative "../lib/buffer"

RSpec.describe Buffer do
  let(:buffer) { Buffer.new "8675309", ["Go", "CSS"] }
  let(:repo1) { double language: "JavaScript" }
  let(:repo2) { double language: "Go" }
  let(:repo3) { double language: "CSS" }

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

    it "rejects dupes" do
      buffer.injest [repo2, repo2]
      expect(buffer.repos).to eq [repo2]
    end
  end
end
