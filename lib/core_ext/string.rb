require "cgi"

class String
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
end
