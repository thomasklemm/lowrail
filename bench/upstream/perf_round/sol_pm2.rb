$LOAD_PATH.unshift(*%w[activesupport actionview activemodel actionpack].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "action_view"
v = ActionView::Base.empty
mk = ->(s, &b) { k = +s; k.singleton_class.class_eval(&b); k.freeze }
cases = {
  "blank, to_s nonblank" => mk.(" ") { def to_s = "title" },
  "nonblank, blank? true" => mk.("x") { def blank? = true },
  "blank, to_s raises" => mk.(" ") { def to_s = raise("boom") },
  "nonblank, to_s blank" => mk.("a") { def to_s = " " },
  "both: blank? true, to_s nonblank" => mk.("x") { def blank? = true; def to_s = "y" },
}
Symbol.class_eval { alias_method :__orig_blank?, :blank? }
cases.each { |n, k| puts "#{n}: #{(v.tag("img", { k => "hello" }) rescue "#{$!.class}: #{$!.message}")}" }
class Symbol; def blank? = (self == :zap) || empty?; end
puts "Symbol#blank? override: #{v.tag("img", { zap: "1" })}"
