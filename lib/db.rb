require "sequel"
require "sqlite3"

module DB
  @gh = Sequel.sqlite(File.join(ENV.fetch("DB_DIR", "."), "github.db"))

  def self.create
    unless @gh.table_exists? :listings
      @gh.create_table :listings do
        primary_key :id
        Bignum :github_id, null: false, index: true
        Date :date, null: false, index: true
        String :name, null: false
        index [:github_id, :date], unique: true
      end
    end
  end

  def self.insert date, repo
    @gh[:listings].insert date: date, github_id: repo.id, name: repo.full_name
  rescue Sequel::UniqueConstraintViolation
    false
  end

  def self.count *args
    date, repo = args

    if repo
      @gh[:listings].where(github_id: repo.id).where("date <= ?", date).count
    elsif date
      @gh[:listings].where("date = ?", date).count
    else
      @gh[:listings].count
    end
  end
end

DB.create
