require_relative "./github"
require_relative "./rejection_log"
require_relative "./repo"

# Repos created on `day` that already have a few stars, best first.
#
# This list used to come from GitHub Archive: WatchEvents for repos that also
# had a CreateEvent that day. GitHub's public event feed stopped carrying
# repository CreateEvents in October 2025, so that query went empty. The search
# API answers the same question directly.
#
# Stars are the repo's total at the time we ask. For a repo created today
# that is today's stars, give or take the last few hours.
#
# New repos are where spam concentrates, and the keyword checks alone let it
# through ("pre-activated" software lures, FPS "optimizers"), so this list also
# screens on how the repos and their owners look, not just what they say.
class NewRepos
  MIN_STARS = 10
  PAGES = 3
  CLUSTER_SIZE = 4

  attr_reader :day, :github

  def initialize day, github=GitHub.new
    @day = day
    @github = github
    @accounts = {}
  end

  # `max_lookups` caps the owner lookups, one GitHub API call each.
  def top limit=15, max_lookups=200
    drop_clusters(candidates.select { |repo| acceptable? repo })
      .first(max_lookups)
      .lazy
      .select { |repo| trustworthy_account? repo }
      .first(limit)
  end

  private

  def candidates
    github.search_repositories("created:#{day} stars:>=#{MIN_STARS}", PAGES).map { |item|
      Repo.from_api item, item["stargazers_count"]
    }
  end

  def acceptable? repo
    reason = repo.rejection_reason
    skip repo, reason if reason
    reason.nil?
  end

  # Spam factories stamp out repos that look alike: the same number of stars
  # (they buy a fixed batch) on the same amount of code. Real projects rarely
  # collide on both, so a group of lookalikes is dropped as a whole.
  def drop_clusters repos
    counts = Hash.new(0)
    repos.each { |repo| counts[signature repo] += 1 }

    repos.reject { |repo|
      lookalikes = counts[signature repo]
      skip repo, "one of #{lookalikes} lookalike repos" if lookalikes >= CLUSTER_SIZE
      lookalikes >= CLUSTER_SIZE
    }
  end

  def signature repo
    [repo.stargazers_count, repo[:size].to_i / 2]
  end

  def trustworthy_account? repo
    reason = repo.account_rejection_reason account_for(repo)
    skip repo, reason if reason
    reason.nil?
  rescue => e
    skip repo, "#{e.class}: #{e.message}"
    false
  end

  def account_for repo
    login = repo.owner.login
    @accounts[login] ||= Hashie::Mash.new github.user(login)
  end

  def skip repo, reason
    RejectionLog.skipped day, repo.html_url, repo.stargazers_count, reason
  end
end
