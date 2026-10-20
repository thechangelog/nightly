require_relative "../lib/github"

RSpec.describe GitHub do
  let(:github) { GitHub.new "token" }

  def page count
    {"items" => Array.new(count) { |i| {"id" => i} }}
  end

  describe "#search_repositories" do
    it "asks for the most-starred repos matching the query" do
      allow(github).to receive(:get).and_return page(1)

      github.search_repositories "created:2026-10-19 stars:>=10"

      expect(github).to have_received(:get).with("/search/repositories",
        q: "created:2026-10-19 stars:>=10", sort: "stars", order: "desc", per_page: 100, page: 1)
    end

    it "keeps paging while pages are full" do
      allow(github).to receive(:get).and_return page(100), page(100), page(30), page(100)

      expect(github.search_repositories("q", 4).length).to eq 230
      expect(github).to have_received(:get).exactly(3).times
    end

    it "stops at the requested number of pages" do
      allow(github).to receive(:get).and_return page(100)

      expect(github.search_repositories("q", 2).length).to eq 200
      expect(github).to have_received(:get).exactly(2).times
    end
  end

  describe "#user" do
    it "fetches the account" do
      allow(github).to receive(:get).with("/users/octocat").and_return({"login" => "octocat"})
      expect(github.user("octocat")).to eq({"login" => "octocat"})
    end
  end
end
