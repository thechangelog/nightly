require "sequel"
require "sqlite3"

module DB
  @gh = Sequel.sqlite "github.db"

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

  def self.count
    @gh[:listings].count
  end
end

DB.create
