# Differential harness for R7-5 (Tags::Base#sanitized_value): run in main and candidate, diff.
require "action_view"
require "active_model"

LOG = []
class SubStr < String
  def gsub(*a, &b) = (LOG << "SubStr#gsub"; super)
  def downcase(*) = (LOG << "SubStr#downcase"; super)
end
class Val
  def initialize(s) = @s = s
  def to_s = (LOG << "Val#to_s"; @s)
end
RETAINED = +"Kept Value.X"
SINGLETON = +"Single Ton"
def SINGLETON.gsub(*a, &b) = (LOG << "singleton gsub"; RETAINED)

values = {
  "plain" => "In Progress.v2",
  "frozen" => "Frozen Val".freeze,
  "symbol" => :"Some Symbol",
  "nil" => nil,
  "integer" => 42,
  "float" => 1.5,
  "unicode" => "Ünïcode Ä.ß",
  "binary" => "ab c".b,
  "invalid" => "bad \xFF byte",
  "empty" => "",
  "all removed" => "!!!",
  "subclass" => SubStr.new("Sub Class.X"),
  "to_s plain retained" => Val.new(RETAINED),
  "to_s frozen" => Val.new("Frozen To_s".freeze),
  "to_s subclass" => Val.new(SubStr.new("Sub To_s")),
  "to_s non-string" => Val.new(:sym),
  "to_s singleton gsub (boundary)" => Val.new(SINGLETON),
}

base = ActionView::Helpers::Tags::Base.allocate
values.each do |name, v|
  LOG.clear
  before = RETAINED.dup
  r = begin
    s = base.send(:sanitized_value, v)
    "#{s.inspect} #{s.class} #{s.encoding} frozen=#{s.frozen?} same_as_input=#{s.equal?(v)}"
  rescue => e
    "#{e.class}: #{e.message}"
  end
  puts "sanitized | #{name} | #{r} | retained_unchanged=#{RETAINED == before} | #{LOG.join(', ')}"
end

class Post
  include ActiveModel::Model
  attr_accessor :status, :tags
end
view = ActionView::Base.empty
post = Post.new(status: "In progress", tags: [])
values.each do |name, v|
  next if name == "invalid"
  LOG.clear
  out = [
    -> { view.radio_button(:post, :status, v, object: post) },
    -> { view.check_box(:post, :status, { object: post }, v, "0") },
    -> { view.label(:post, :status, "L", value: v) },
    -> { view.collection_radio_buttons(:post, :status, [[v, "A"]], :first, :last, {}, object: post) },
  ].map do |f|
    f.()
  rescue => e
    "#{e.class}: #{e.message}"
  end
  puts "helpers | #{name} | #{out.join(' ')} | #{LOG.join(', ')}"
end
