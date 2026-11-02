# frozen_string_literal: true

# Census-3b: CodeTriage per-patch GC-enabled deltas (objects/request, median of three).
require "json"
dir = "/home/user/workspace/repo/.lowrail/private/rails-main-census-3"
med = ->(a) { a.sort[1] }
%w[base3 tagstr frozen hwia drop warnings arel].each do |label|
  %w[interpreter yjit].each do |mode|
    a = JSON.parse(File.read("#{dir}/codetriage-#{mode}.json"))["routes"]
    b = JSON.parse(File.read("#{dir}/after-#{label}/codetriage-#{mode}.json"))["routes"]
    puts "| #{label} | #{mode} | " + a.zip(b).map { |x, y| format("%+.1f", med.(y["gc_enabled_objects_per_request"]) - med.(x["gc_enabled_objects_per_request"])) }.join(" / ") + " |"
  end
end
