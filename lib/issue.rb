require_relative "./db"

class Issue
  attr_reader :date, :promotions, :top_new, :top_all
  def initialize date, json
    @date = date
    @promotions = %w(rfc gotime spotlight).sample(2)
    process_top_new json
    process_top_all json
  end

  def promotion_one
    promotions.first
  end

  def promotion_two
    promotions.last
  end

  def top_all_firsts
    top_all.select { |repo| repo.occurrences <= 1 }
  end

  def top_all_repeats
    top_all.select { |repo| repo.occurrences > 1 }
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
