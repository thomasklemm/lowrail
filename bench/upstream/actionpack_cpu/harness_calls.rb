# frozen_string_literal: true

# ruby-bench harness for bet P1: after warmup, count method calls made in the
# request scaffolding (outside send_action and outside Active Record) over
# CALLS_ITRS iterations, keyed by method owner, name and definition site.
# Copy to ruby-bench's harness/ directory and run with HARNESS=lowrail_calls.
#
#   CALLS_OUT=out.tsv CALLS_REQUESTS=2000 HARNESS=lowrail_calls ruby benchmarks/railsbench/benchmark.rb
require_relative "../lib/harness"

# Active Record work, except its wrappers around the whole action/request
# (ControllerRuntime#process_action, executor hooks call through).
AR_WRAPPERS = %i[process_action call run complete].freeze
def ar_work?(t)
  t.event.to_s.start_with?("c_") ? false : t.path.include?("/activerecord/") && !AR_WRAPPERS.include?(t.method_id)
end

def run_benchmark(_n, **, &block)
  Integer(ENV.fetch("WARMUP_ITRS", 5)).times(&block)
  counts = Hash.new(0)
  skip = 0 # depth inside send_action or Active Record
  in_request = 0
  skip_methods = %i[send_action]
  tp = TracePoint.new(:call, :return, :c_call, :c_return) do |t|
    case t.event
    when :call, :c_call
      m = t.method_id
      if m == :call && t.defined_class == Rails::Engine
        in_request += 1
      end
      if skip_methods.include?(m) || ar_work?(t)
        skip += 1
      elsif skip.zero? && in_request > 0
        counts[[t.defined_class, m, t.event == :c_call ? "<c>" : "#{t.path.sub(%r{.*/(rails-wt/[^/]+/|gems/)}, "")}:#{t.lineno}"]] += 1
      end
    else
      m = t.method_id
      skip -= 1 if skip_methods.include?(m) || ar_work?(t)
      in_request -= 1 if m == :call && t.defined_class == Rails::Engine
    end
  end
  itrs = Integer(ENV.fetch("CALLS_ITRS", 1))
  tp.enable { itrs.times(&block) }
  requests = Integer(ENV.fetch("CALLS_REQUESTS")) * itrs
  File.open(ENV.fetch("CALLS_OUT"), "w") do |f|
    counts.sort_by { -_2 }.each do |(owner, m, site), c|
      f.puts [format("%.2f", c.to_f / requests), owner.inspect, m, site].join("\t")
    end
  end
  warn "counted #{requests} requests -> #{ENV["CALLS_OUT"]}"
end
