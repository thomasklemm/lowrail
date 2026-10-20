# frozen_string_literal: true

# Discovery only; never a timing arm. Same artificial heap as heap_requests.rb.
$LOAD_PATH.unshift(*Gem::Specification.find_by_name("stackprof").full_require_paths)
require File.expand_path("config/application", Dir.pwd)
Rails.application.config.yjit = false
require File.expand_path("config/environment", Dir.pwd)
require "stackprof"
require "rack/mock"
require "json"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "expected off/interpreter" if defined?(Lowrail) || RubyVM::YJIT.enabled?
client = Rack::MockRequest.new(Rails.application)
request = -> { client.get(ARGV.fetch(0), "HTTP_HOST" => "localhost", "HTTPS" => "on").tap { raise _1.status.to_s unless _1.status == 200 } }
50.times { request.call }
3.times { GC.start }
GC.disable
anchors = []
GC.stat_heap.each do |pool, stats|
  count = [Integer(ENV.fetch("RUBY_GC_HEAP_#{pool}_INIT_SLOTS")) - stats[:heap_live_slots], 0].max
  fillers = Array.new(count) { Array.new([0, 4, 9, 19, 39].fetch(pool)) }
  stride = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / stats[:slot_size] / 2
  fillers.each_with_index { |object, index| anchors << object if (index % stride).zero? }
  anchors << fillers.last unless fillers.empty?
  fillers.clear
end
GC.enable
3.times { GC.start }
profile = StackProf.run(mode: :cpu, interval: 100, raw: true) { 500.times { request.call } }
File.write(ARGV.fetch(1), JSON.generate(profile))
response = request.call
File.write(ARGV.fetch(1) + ".html", response.body)
puts JSON.generate(ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, anchors: anchors.size,
  headers: response.headers, bytes: response.body.bytesize, samples: profile[:samples])
