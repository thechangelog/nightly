require_relative "../../lib/core_ext/string"

RSpec.describe "String extensions" do
  describe "#html_escape" do
    it "escapes html characters" do
      string = "High performance <canvas>"
      expect(string.html_escape).to eq "High performance &lt;canvas&gt;"
    end
  end

  describe "#linkify" do
    it "detects http(s) links and wraps anchor tags around them" do
      string = "Check out https://github.com/thechangelog and also http://test.com"
      expect(string.linkify).to eq "Check out <a href='https://github.com/thechangelog'>https://github.com/thechangelog</a> and also <a href='http://test.com'>http://test.com</a>"
    end
  end
end
