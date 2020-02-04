require_relative "../../lib/core_ext/string"

RSpec.describe "String extensions" do
  describe "#emojify" do
    it "takes :emoji: and turns them in to img tags pointing at emoji images" do
      string = "I :heart: this let's :shipit:!"
      expect(string.emojify).to eq "I ❤️ this let's <img alt='shipit' src='/images/emoji/shipit.png' style='vertical-align:middle' width='20' height='20' />!"
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

  describe "#translate_url" do
    it "CGI escapes text and returns correct URL" do
      expect("h i".translate_url).to eq "https://translate.google.com/#view=home&op=translate&sl=auto&tl=auto&text=h%20i"
    end
  end

  describe "#twitterized" do
    it "truncates to 250 characters when no tags given" do
      expect(("X" * 250).twitterized.length).to eq 250
    end

    it "truncates to 250 - tags length when tags given" do
      twitterized = ("X" * 250).twitterized "#test #ing"
      expect(twitterized.length).to eq 250
      expect(twitterized).to end_with("... #test #ing")
    end

    it "leaves shorter ones alone" do
      string = "this is short"
      expect(string.twitterized).to eq "this is short"
    end

    it "purges :emoji: references" do
      string = "this is :cool: :stuff: bro"
      expect(string.twitterized).to eq "this is bro"
    end

    it "purges urls" do
      string = "check out my homepage https://changelog.com it is rad"
      expect(string.twitterized).to eq "check out my homepage it is rad"
    end

    it "unescapes html entities" do
      string = "&quot;Takin&#39; care of business, workin&#39; overtime&quot;"
      expect(string.twitterized).to eq %{"Takin' care of business, workin' overtime"}
    end
  end
end
