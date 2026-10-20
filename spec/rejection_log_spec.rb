require "date"
require_relative "../lib/rejection_log"

RSpec.describe RejectionLog do
  it "writes one line per skipped repo to stderr" do
    expect {
      RejectionLog.skipped Date.new(2026, 10, 19), "https://example.com/r", 42, "malware"
    }.to output("[nightly] 2026-10-19 skipped https://example.com/r (42 stars): malware\n").to_stderr
  end
end
