require "active_record"
require_relative "prototype"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
dir = "/home/user/workspace/src/rails-main/activerecord/test/models"
$LOAD_PATH.unshift File.dirname(dir)
errors = 0
pending = Dir["#{dir}/**/*.rb"].sort
3.times do
  pending = pending.reject do |f|
    require f
    true
  rescue NameError, StandardError, LoadError
    false
  end
end
puts "files #{Dir["#{dir}/**/*.rb"].size}, not loaded #{pending.size}"
ShadowCheck::HITS.each { puts "#{_1[:model]}.#{_1[:name]} (#{_1[:owner]}) #{_1[:location]}" }
