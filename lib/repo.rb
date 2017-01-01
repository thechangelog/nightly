require "hashie/mash"
require "open-uri"
require_relative "./core_ext/string"

class Repo < Hashie::Mash
  HALL_OF_FAME = %w(FreeCodeCamp)

  def self.from_github url, stars_count
    repo = new JSON.load open("#{url}?access_token=#{ENV["GITHUB_TOKEN"]}")
    repo.new_stargazers_count = stars_count
    repo.description = (repo.description || "").html_escape
    repo
  end

  def self.from_json hash
    new hash
  end

  def classy_description
    description.linkify.emojify
  end

  def hall_of_famer?
    HALL_OF_FAME.include? name
  end

  def language_param
    case language
    when "c#" then "csharp"
    else
      language
    end
  end

  def language_trending_url
    "https://github.com/trending?l=#{language_param}"
  end

  def no_description?
    (description || "").strip.empty?
  end
end
