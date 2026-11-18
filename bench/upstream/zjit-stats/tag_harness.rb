require_relative "../lib/harness"

# ruby-bench harness (copy to harness/ztag.rb) for the lobsters exit at TagBuilder#content_tag_string:
# counts the classes interpolated at tag_helper.rb:232 per iteration. Interpreter only; writes $TAG_JSON.
def run_benchmark(_num_itrs_hint, **, &block)
  5.times { block.call }
  counts = Hash.new(0)
  ActionView::Helpers::TagHelper::TagBuilder.prepend(Module.new do
    define_method(:content_tag_string) do |name, content, options, escape = true|
      tag_options = tag_options(options, escape) if options
      c = escape && content.present? ? ERB::Util.unwrapped_html_escape(content) : content
      counts["name=#{name.class} tag_options=#{tag_options.class} content=#{c.class}"] += 1
      super(name, content, options, escape)
    end
  end)
  3.times { block.call }
  require "json"
  File.write(ENV.fetch("TAG_JSON"), JSON.pretty_generate(counts.sort_by { -_2 }.to_h { |k, v| [k, v / 3.0] }) + "\n")
end
