# frozen_string_literal: true

# ruby-bench harness (copy into ruby-bench/harness/): redefines Action View
# 8.1's TagBuilder#tag_option in every variant, so base and candidates run the
# same redefined method; TAG_VARIANT picks base, t1 (String values first) or
# t2 (Array values joined without safe_join). One Callgrind window of
# IR_ITRS iterations inside Array#cycle after WARMUP_ITRS, GC disabled.
require_relative "../lib/harness"

def lowrail_tag_patch(variant)
  string_branch = variant == "t1" ? "when String\n  value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s\n" : ""
  join = if variant == "t2"
    'value.flatten.map! { |v| ERB::Util.unwrapped_html_escape(v) }.join(" ")'
  else
    '@view_context.safe_join(value, " ")'
  end
  ActionView::Helpers::TagHelper::TagBuilder.class_eval <<~RUBY, __FILE__, __LINE__ + 1
    private def tag_option(key, value, escape)
      key = ERB::Util.xml_name_escape(key) if escape

      case value
      #{string_branch}when Array, Hash
        value = ActionView::Helpers::TagHelper.build_tag_values(value) if key.to_s == "class"
        value = escape ? #{join} : value.join(" ")
      when Regexp
        value = escape ? ERB::Util.unwrapped_html_escape(value.source) : value.source
      else
        value = escape ? ERB::Util.unwrapped_html_escape(value) : value.to_s
      end
      value = value.gsub('"', "&quot;") if value.include?('"')

      %(\#{key}="\#{value}")
    end
  RUBY
end

def run_benchmark(_n, **, &block)
  lowrail_tag_patch(ENV.fetch("TAG_VARIANT"))
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "1"))
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations, variant=#{ENV["TAG_VARIANT"]}"
end
