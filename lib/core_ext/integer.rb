class Integer
  def comma_separated
    self.to_s.chars.reverse.each_slice(3).map(&:reverse).map(&:join).reverse.join ","
  end
end
