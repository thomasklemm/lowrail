require "bundler/setup"
require "active_record"

patch = File.read(File.expand_path("../variant-row-read.diff", __dir__))
methods = patch.lines.grep(/^\+/).reject { |line| line.start_with?("+++") }.map { |line| line.delete_prefix("+") }.join
ActiveModel.module_eval("class LazyIndexedAttributeSet\n#{methods}\nend", __FILE__, 7)
