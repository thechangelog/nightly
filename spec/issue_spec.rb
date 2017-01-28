require_relative "../lib/issue"

RSpec.describe Issue do
  let(:issue) { Issue.new "2017-01-01", {"top_all" => [], "top_new" => []} }

  describe "#top_all_firsts" do
    it "returns repos which have one or less occurrences" do
      nope = double occurrences: 2
      yep = double occurrences: 1
      expect(issue).to receive(:top_all).and_return [nope, yep]
      expect(issue.top_all_firsts).to eq [yep]
    end
  end

  describe "#teaser" do
    it "uses top_all_firsts if there are any" do
      allow(issue).to receive(:top_all_firsts).and_return [double(name: "Repo 1"), double(name: "Repo 2")]
      expect(issue.teaser).to eq "Repo 1, Repo 2 and more!"
    end

    it "falls back to top_new when there are no top_all_firsts" do
      allow(issue).to receive(:top_all_firsts).and_return []
      allow(issue).to receive(:top_new).and_return [double(name: "Repo 1")]
      expect(issue.teaser).to eq "Repo 1 and more!"
    end
  end

  describe "#top_all_repeats" do
    it "returns repos which have between 2 and 100 occurrences" do
      nope1 = double occurrences: 1
      nope2 = double occurrences: 101
      yep = double occurrences: 58
      expect(issue).to receive(:top_all).and_return [nope1, nope2, yep]
      expect(issue.top_all_repeats).to eq [yep]
    end
  end
end
