require "hashie/mash"

class Repo < Hashie::Mash
  def language_param
    case language
    when "c#" then "csharp"
    else
      language
    end
  end

  def language_trending_url
    "https://github.com/trending?l=#{language_param}"
  end
end
