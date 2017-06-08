require "pry"
require "hashie/mash"
require "yaml"
require "obscenity"
require "open-uri"
require_relative "./core_ext/string"

class Repo < Hashie::Mash
  def self.from_github url, stars_count
    repo = new JSON.load open("#{url}?access_token=#{ENV["GITHUB_TOKEN"]}")
    repo.new_stargazers_count = stars_count
    repo.description = (repo.description || "").html_escape
    repo
  end

  def self.from_json hash
    new hash
  end

  def initialize hash={}
    super hash
    self.occurrences = 1
  end

  def classy_description
    description.linkify.emojify
  end

  def language_class
    case language
    when "c#" then "csharp"
    else
      language.downcase.strip.gsub(" ", "-").gsub(/[^\w-]/, "")
    end
  end

  def language_trending_url
    "https://github.com/trending/#{language_class}"
  end

  def no_description?
    (description || "").strip.empty?
  end

  def obscene?
    [description, name, owner.login].any? { |text|
      Obscenity::Base.blacklist.any? { |black|
        !!(text =~ /#{black}/i) # not using .profane? because its regex
        }                       # doesn't catch partial word matches
      }
  end
end
