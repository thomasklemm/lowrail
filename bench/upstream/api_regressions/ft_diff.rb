require "action_view"
fx = ARGV[0]
lc = ActionView::LookupContext.new([fx], {})
show = ->(label, &b) { r = (b.call rescue $!); puts "#{label}: #{r.is_a?(Exception) ? r.class.name : [r.class.name, r.virtual_path, r.format, r.short_identifier].inspect}" }
show.("plain")       { lc.find_template("hello_world", %w(test)) }
show.("rabl-style")  { lc.find_template("test/hello_world", [], false) }
show.("partial")     { lc.find_template("customer", %w(test), true, [:customer], {}) }
show.("thredded")    { lc.find_template("test/customer", [], true, [:customer], {}) }
show.("formats opt") { lc.find_template("hello_world", %w(test), false, [], formats: [:html]) }
show.("missing")     { lc.find_template("nope", %w(test)) }
show.("missing partial") { lc.find_template("nope", %w(test), true) }
I18n.available_locales = [:en, :da]; lc.locale = :da
show.("locale da")   { lc.find_template("hello_world", %w(test)) }
