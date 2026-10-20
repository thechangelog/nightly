require "pry"
require "hashie/mash"
require "yaml"
require "obscenity"
require "whatlanguage"
require "open-uri"
require "time"
require_relative "./core_ext/string"

class Repo < Hashie::Mash
  OBSCENITY_SUBSTRING_MIN = 5
  THROWAWAY_ACCOUNT_DAYS = 30
  THROWAWAY_MAX_REPOS = 3
  TINY_REPO_KB = 50
  ESTABLISHED_FOLLOWERS = 5
  ESTABLISHED_ACCOUNT_DAYS = 365

  def self.from_github url, stars_count
    from_api JSON.load(open(url, "Authorization" => %{token #{ENV["GITHUB_TOKEN"]}})), stars_count
  end

  def self.from_api hash, stars_count
    repo = new hash
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

  def blocked?
    blocked_github_repo_ids.include?(id) ||
    blocked_github_user_ids.include?(owner.id)
  end

  def classy_description
    description.linkify.emojify
  end

  def text_description
    description.html_unescape
  end

  def description
    self[:description] || ""
  end

  def english?
    WhatLanguage.new(:all).language(description) == :english
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

  def no_language?
    (language || "").strip.empty?
  end

  def description_too_short?
    (description.length < 5) || (description.split(" ").length < 3)
  end

  def description_too_long?
    description.length > 280
  end

  # Short blocklist entries ("ass", "ho", "kill") sit inside everyday words
  # ("assistant", "Python", "skills"), so they only count as a token of their
  # own. Longer entries still match anywhere, which catches compounds like
  # "NiggerFoundation".
  def obscene?
    [description, name, owner.login].any? { |text| obscene_text? text.to_s }
  end

  def malware?
    [description, name].any?(&:malware?) ||
      description.downcase.near_match?(name.downcase)
  end

  def too_many_new_stars?
    new_stargazers_count > stargazers_count
  end

  # Spam factories sell stars to accounts that exist to push a repo: nobody
  # follows them, and they are either days old or hold a handful of repos with
  # this one barely containing anything. `account` is the /users/:login payload.
  def throwaway_account? account, now=Time.now
    return false unless account.followers.to_i == 0

    account_age_days(account, now) < THROWAWAY_ACCOUNT_DAYS ||
      (account.public_repos.to_i <= THROWAWAY_MAX_REPOS && self[:size].to_i < TINY_REPO_KB)
  end

  def established_account? account, now=Time.now
    account.followers.to_i >= ESTABLISHED_FOLLOWERS ||
      account_age_days(account, now) >= ESTABLISHED_ACCOUNT_DAYS
  end

  # Topics the malware list objects to ("free-tuition", "cracked").
  def suspicious_topics?
    (topics || []).any?(&:malware?)
  end

  # Why the account behind this repo makes it look like spam, or nil. Topics
  # alone hit real projects (a "roblox" tagged tool), so they only count
  # against accounts that haven't established themselves.
  def account_rejection_reason account, now=Time.now
    return "throwaway account" if throwaway_account? account, now
    return "suspicious topics" if suspicious_topics? && !established_account?(account, now)
  end

  # Why this repo shouldn't be listed, or nil when it should be.
  def rejection_reason
    return "blocked" if blocked?
    return "malware url" if url.to_s.malware? # owner and repo name, as in the API url
    return "malware" if malware? # run it again now that we have more info
    return "description too short" if description_too_short?
    return "description too long" if description_too_long?
    return "obscene" if obscene?
    return "too many new stars" if too_many_new_stars?
  end

  private

  def account_age_days account, now
    return ESTABLISHED_ACCOUNT_DAYS unless account.created_at # unknown: don't judge by age

    ((now - Time.parse(account.created_at)) / 86_400).floor
  end

  def obscene_text? text
    blocked_words.any? { |blocked|
      if blocked.length >= OBSCENITY_SUBSTRING_MIN
        !!(text =~ /#{Regexp.escape blocked}/i)
      else
        token_in? text, blocked
      end
    }
  end

  # A token is delimited by anything that isn't a letter ("91porn",
  # "my_porn_site") or by a camelCase hump ("techGay").
  def token_in? text, word
    pattern = /#{Regexp.escape word}/i
    position = 0

    while (match = pattern.match text, position)
      from, to = match.begin(0), match.end(0)
      return true if token_start?(text, from) && token_end?(text, to)
      position = from + 1
    end

    false
  end

  def token_start? text, from
    from == 0 ||
      text[from - 1] !~ /[[:alpha:]]/ ||
      (text[from - 1] =~ /[[:lower:]]/ && text[from] =~ /[[:upper:]]/)
  end

  def token_end? text, to
    to == text.length ||
      text[to] !~ /[[:alpha:]]/ ||
      (text[to - 1] =~ /[[:lower:]]/ && text[to] =~ /[[:upper:]]/)
  end

  def blocked_github_repo_ids
    [156648725]
  end

  def blocked_github_user_ids
    [34570255, 48942249, 114510212]
  end

  def blocked_words
    Obscenity::Base.blacklist + %w(gay porn)
  end
end
