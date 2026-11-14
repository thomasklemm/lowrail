# frozen_string_literal: true
# Ir per call of the steps button_to now runs through form_tag on main (scratch, census 9).
# RAILS=~/c9/main valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null ruby bt_steps.rb
src = File.read(File.join(__dir__, "req_micro.rb"))
eval(src.sub(/^n = Integer.*\z/m, ""), TOPLEVEL_BINDING)
V = CSRF
URL = V.posts_path
FO = { "class" => "button_to", "method" => "post", "enforce_utf8" => false, "authenticity_token" => nil }.freeze
HO = V.send(:html_options_for_form, URL, FO).freeze
BTN = V.tag("input", "type" => "submit", "value" => "New")
EXTRA = V.send(:extra_tags_for_form, HO.dup)
HO2 = HO.except("authenticity_token", "enforce_utf8").freeze
STEPS = {
  "stringify_keys" => -> { FO.stringify_keys },
  "html_options_for_form" => -> { V.send(:html_options_for_form, URL, FO) },
  "url_for(String)" => -> { V.url_for(URL) },
  "extra_tags_for_form" => -> { V.send(:extra_tags_for_form, HO.dup) },
  "safe_join" => -> { V.safe_join([EXTRA, BTN]) },
  "content_tag form 4 attrs" => -> { V.content_tag(:form, BTN, HO2) },
  "content_tag form w/o accept-charset" => -> { V.content_tag(:form, BTN, HO2.except("accept-charset")) },
  "form_tag_with_body" => -> { V.send(:form_tag_with_body, HO.dup, BTN) },
  "capture" => -> { V.capture { BTN } },
}
IrCount.start if IrCount.running?
STEPS.each do |name, fn|
  300.times { fn.() }
  GC.start; GC.disable
  o0 = GC.stat(:total_allocated_objects); i0 = IrCount.now
  200.times { fn.() }
  i1 = IrCount.now; o1 = GC.stat(:total_allocated_objects); GC.enable
  puts format("%-38s %10.1f %6.2f", name, (i1 - i0) / 200.0, (o1 - o0) / 200.0)
end
