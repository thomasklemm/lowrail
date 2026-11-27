# frozen_string_literal: true

load File.expand_path("../rebuild-2026-11-27/l6_keys_callers.rb", __dir__)

def key_calls
  calls = 0
  trace = TracePoint.new(:call) do |event|
    calls += 1 if event.defined_class == ActiveModel::LazyIndexedAttributeSet && event.method_id == :keys
  end
  trace.enable { yield }
  calls
end

post = Post.first
post.update!(count_0: 20)
puts "default update keys=#{key_calls { post.update!(count_0: 21) }}"
Post.partial_updates = false
puts "partial_updates=false keys=#{key_calls { post.update!(count_0: 22) }}"
