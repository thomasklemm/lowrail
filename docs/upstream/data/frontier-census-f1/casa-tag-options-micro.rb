require "active_support/all"
require "bigdecimal"
require "action_view"
include ActionView::Helpers::TagHelper
include ActionView::Helpers::FormTagHelper
include ActionView::Helpers::UrlHelper
Opt = Struct.new(:id)
n = Integer(ENV.fetch("N", "20000"))
stress_every = Integer(ENV.fetch("STRESS_EVERY", "0"))
n.times do |i|
  opts = { class: "form-control #{i}", data: { id: i, action: "x#{i}", "turbo-frame" => "f#{i % 7}" }, placeholder: "p#{i}", disabled: i.odd?, "aria-label" => [:a, i.to_s], value: Opt.new(i).id.to_s }
  GC.stress = (stress_every > 0 && i % stress_every == 0)
  text_field_tag("q#{i}", "v#{i}", opts)
  tag.input(**opts)
  check_box_tag("c", "1", i.even?, opts.merge(id: nil))
  GC.stress = false
end
puts "ok #{n}"
p RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :side_exit_count, :compile_error_out_of_memory) if RubyVM::ZJIT.enabled? && RubyVM::ZJIT.stats_enabled?
