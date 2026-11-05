$LOAD_PATH.unshift(*%w[activesupport actionview activemodel actionpack].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "action_view"
class Sub < String; end
class BlankWhenConverted < String; def to_s = " "; end
class NeverBlank < String; def blank? = false; end
class Flip < String; def initialize(*) = (super; @n = 0); def to_s = ((@n += 1) == 1 ? "first" : ""); end
class WeirdBlank; def blank? = false; def to_s = "  "; end
class WeirdName; def blank? = false; def to_s = "w"; end
class EmptyThing; def blank? = true; def to_s = "e"; end
v = ActionView::Base.empty
s1 = +"a"; def s1.to_s = " "; s1.freeze
s2 = "a".dup.extend(Module.new { def to_s = " " }).freeze
s3 = +" "; def s3.blank? = false; s3.freeze
keys = [s1, s2, s3, :href, "href", :" ", " ", "", :"", "\u00a0", :"\u00a0", nil, false, true, 1, 0, [], {}, Sub.new("sub"), Sub.new("  "), "x".html_safe, " ".html_safe,
        WeirdBlank.new, WeirdName.new, EmptyThing.new, BlankWhenConverted.new("a"), NeverBlank.new(" "), NeverBlank.new(""), Flip.new("a"), ActiveSupport::SafeBuffer.new(" "), ActiveSupport::SafeBuffer.new("a b"), Sub.new("hidden"),  :data, "data", :aria, "aria", :class, "class", :hidden, "hidden", :disabled, "disabled", "\t\n", "a b", "é", "é".encode("UTF-16LE"), "x".b, "\xff".b]
vals = ["v", nil, true, false, :sym, 1, ["a", "b"], { "k" => 1, k2: 2, " " => 3, :" " => 4, "" => 5, nil => 6 }, { "": nil }]
keys.each do |k|
  vals.each do |val|
    out = begin
      v.tag.div(**{}) && v.content_tag(:div, "", { k => val })
    rescue => e
      "#{e.class}: #{e.message[0, 60]}"
    end
    puts "#{k.inspect} => #{val.inspect}: #{out.inspect}"
  end
end
