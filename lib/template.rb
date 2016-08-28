require "erb"

class Template
  def self.view_path= path
    @view_path = path
  end

  def self.view_path
    @view_path || "views"
  end

  def self.partial path, locals={}
    new(path).render locals
  end

  attr_reader :erb
  def initialize path
    @erb = ERB.new File.read "#{Template.view_path}/#{path}.erb"
  end

  def assign_locals locals
    locals.each do |name, value|
      self.class.send :define_method, name do
        value
      end
    end
  end

  def render locals={}
    assign_locals locals
    @erb.result binding
  end
end
