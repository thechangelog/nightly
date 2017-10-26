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

  def html_unescape
    CGI.unescapeHTML self
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

  def truncate length
    return self if self.length <= length
    self[0..(length - 4)] + "..."
  end

  def twitterized tags=""
    s = self
      .gsub(/:([\w+-]+):/, "")
      .gsub(/https?:\/\/.*?\s/, "")
      .squeeze(" ")
      .html_unescape

    if !tags.empty? && !tags.start_with?(" ")
      tags = tags.prepend " "
    end

    s.truncate(115 - tags.length) + tags
  end
end
