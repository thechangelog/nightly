require "erb"

class Template
  def self.view_path= path
    @view_path = path
  end

  def self.view_path
    @view_path || "views"
  end

  def self.partial name, locals={}
    new("_#{name}").render locals
  end

  attr_reader :erb
  def initialize name
    @erb = ERB.new File.read "#{Template.view_path}/#{name}.erb"
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
