require_relative "../../lib/core_ext/string"

RSpec.describe "String extensions" do
  describe "#emojify" do
    it "takes :emoji: and turns them in to img tags pointing at emoji images" do
      string = "I :heart: this let's :shipit:!"
      expect(string.emojify).to eq "I <img alt='heart' src='/images/emoji/unicode/2764.png' style='vertical-align:middle' width='20' height='20' /> this let's <img alt='shipit' src='/images/emoji/shipit.png' style='vertical-align:middle' width='20' height='20' />!"
    end
  end

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
