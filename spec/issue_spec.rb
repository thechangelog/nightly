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
