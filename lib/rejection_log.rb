# One line per candidate we decline to list, so an empty issue explains itself
# in the logs instead of silently shrinking.
module RejectionLog
  def self.skipped day, url, stars, reason
    $stderr.puts "[nightly] #{day} skipped #{url} (#{stars} stars): #{reason}"
  end
end
