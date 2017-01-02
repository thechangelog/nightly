require "cgi"
require "emoji"

class String
  def emojify
    self.gsub(/:([\w+-]+):/) do |match|
      if emoji = Emoji.find_by_alias($1)
        "<img alt='#{$1}' src='/images/emoji/#{emoji.image_filename}' style='vertical-align:middle' width='20' height='20' />"
      else
        match
      end
    end
  end

  def html_escape
    CGI.escapeHTML self
  end

  def linkify
    self.split.map { |word|
      if word.match /\Ahttps?:\/\//
        "<a href='#{word}'>#{word}</a>"
      else
        word
      end
    }.join " "
  end

  def twitterized
    s = self
      .gsub(/:([\w+-]+):/, "")
      .gsub(/https?:\/\/.*?\s/, "")
      .squeeze(" ")

    s.length > 115 ? s[0..111] + "..." : s
  end
end
