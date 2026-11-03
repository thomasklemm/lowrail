require_relative "../analyze"
MARK = [
  [:template_compile, /\AActionView::Template#compile!\z/],
  [:schema_load, /#load_schema!\z|ModelSchema::ClassMethods#load_schema\z/],
  [:attribute_methods, /#define_attribute_methods\z/],
  [:i18n, /I18n::Backend::Base#load_translations|init_translations/],
  [:routes, /RoutesReloader#(reload!|execute)/],
  [:autoload, /\AZeitwerk::Loader::Callbacks#on_file_autoloaded|\AZeitwerk::Loader::Callbacks#on_dir_autoloaded|Zeitwerk::Loader#autoload_file|\AModule#const_missing|\AKernel#require\z/],
  [:unload_and_setup, /\AZeitwerk::Loader#(reload|unload|setup)\z|ActiveSupport::Dependencies.clear|DescendantsTracker/],
  [:reloader_callbacks, /\AActiveSupport::Reloader.reload!|ActiveSupport::Reloader#class_unload!|\AActiveSupport::Reloader.run!/],
  [:executor, /\AActionDispatch::Executor#call\z/],
]
ARGV.each do |path|
  r, p, fr = BootAnalyze.load(path)
  w = BootAnalyze.weight(p); t = Hash.new(0.0)
  p["stacks"].each do |s, c|
    names = s.map { fr[_1]&.first.to_s }
    k = :gc if names.first.start_with?("(garbage")
    k ||= names.reverse_each.lazy.map { |n| MARK.find { |_, re| n.match?(re) }&.first }.find(&:itself) || :other
    t[k] += c * w
  end
  tot = t.values.sum
  puts "## #{r["app"]} reload request: #{tot.round} ms sampled; " + t.sort_by { -_2 }.map { |k, v| "#{k} #{v.round} (#{(100 * v / tot).round}%)" }.join(", ")
end
