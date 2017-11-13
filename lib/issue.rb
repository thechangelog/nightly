require_relative "./db"
require_relative "./repo"

class Issue
  attr_reader :date, :promotions, :top_new, :top_all
  def initialize date, json
    @date = date
    @promotions = %w(community gotime rfc feedback master).sample 2
    process_top_new json
    process_top_all json
  end

  def promotion_one
    promotions.first
  end

  def promotion_two
    promotions.last
  end

  def teaser
    repos = (top_all_firsts + top_new + top_all_repeats).first 5
    repos.map(&:name).join(", ") + " and more!"
  end

  def top_all_firsts
    top_all.select { |repo| (0..1).include? repo.occurrences }
  end

  def top_all_repeats
    top_all.select { |repo| (2..100).include? repo.occurrences }
  end

  private

  def process_top_new json
    @top_new = json["top_new"].map { |j| Repo.from_json j }
  end

  def process_top_all json
    @top_all = json["top_all"].map { |j|
      repo = Repo.from_json j
      repo.occurrences = DB.count date, repo
      repo
    }
  end
end
