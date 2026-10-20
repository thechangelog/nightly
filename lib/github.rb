require "json"
require "open-uri"

# The slice of the GitHub REST API the nightly needs.
class GitHub
  API = "https://api.github.com".freeze
  PER_PAGE = 100

  def initialize token=ENV["GITHUB_TOKEN"]
    @token = token
  end

  def get path, params={}
    uri = URI.parse "#{API}#{path}"
    uri.query = URI.encode_www_form params unless params.empty?

    JSON.load uri.open(
      "Authorization" => %{token #{@token}},
      "Accept" => "application/vnd.github+json",
      "User-Agent" => "changelog-nightly"
    )
  end

  # Most-starred first. The search API serves at most 1,000 results.
  def search_repositories query, pages=3
    items = []

    (1..pages).each do |page|
      batch = get("/search/repositories",
        q: query, sort: "stars", order: "desc", per_page: PER_PAGE, page: page)["items"]
      items.concat batch
      break if batch.length < PER_PAGE
    end

    items
  end

  def user login
    get "/users/#{login}"
  end
end
