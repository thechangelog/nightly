require_relative "../../lib/core_ext/integer"

RSpec.describe "String extensions" do
  describe "#comma_separated" do
    it "converts to comma separated string" do
      expect(0.comma_separated).to eq "0"
      expect(23.comma_separated).to eq "23"
      expect(134.comma_separated).to eq "134"
      expect(1234.comma_separated).to eq "1,234"
      expect(48955.comma_separated).to eq "48,955"
      expect(1_000_000.comma_separated).to eq "1,000,000"
    end
  end
end
