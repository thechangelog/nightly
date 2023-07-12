require "cgi"
require "emoji"

# Derive all custom emoji from images on disk
Dir["images/emoji/*.png"].each do |image|
  name = image.split("/").last.gsub ".png", ""
  Emoji.create name
end

class String
  def emojify
    self.gsub(/:([\w+-]+):/) do |match|
      if emoji = Emoji.find_by_alias($1)
        if emoji.custom?
          "<img alt='#{$1}' src='/images/emoji/#{emoji.image_filename}' style='vertical-align:middle' width='20' height='20' />"
        else
          emoji.raw
        end
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

  def malware?
    %w(cheat ch3at 0ptions sk1n hack spoof sp00f spoofer sp00f3r aimbot godlike
    g0dlike d4rk s1d3 roblox r0blox r0bl0x crack cracked scr1pt ap3x unl0cker
    unl0ck3r h4ck m0ney 0day exploit expl0it).any? { |i| !!(self =~ /#{i}/i) }
  end

  def near_match? other, percent=80
    min_length = [self.length, other.length].min

    match_count = 0

    min_length.times do |i|
      match_count += 1 if self[i] == other[i]
    end

    (match_count.to_f / min_length) * 100 >= percent
  end

  def translate_url
    text = URI.encode self
    "https://translate.google.com/#view=home&op=translate&sl=auto&tl=auto&text=#{text}"
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

    s.truncate(250 - tags.length) + tags
  end
end
