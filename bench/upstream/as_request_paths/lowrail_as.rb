# frozen_string_literal: true

# ruby-bench harness (copy into ruby-bench/harness/): AS=fanout|extract, CAND=0|1.
# Every variant redefines the method with Rails main's body or the candidate's, so main and
# candidate pay the same redefinition cost. Rails 8.1's Handle.new still takes the notifier.
# COUNT=1 counts calls per iteration with a TracePoint instead of measuring.
require_relative "../lib/harness"

def lowrail_as_patch(which, cand)
  case which
  when "fanout"
    body = if cand
      "instances = []\n groups.each { |group_klass, grouped_listeners| instances << group_klass.new(grouped_listeners, name, id, payload) }"
    else
      "instances = groups.map { |group_klass, grouped_listeners| group_klass.new(grouped_listeners, name, id, payload) }"
    end
    ActiveSupport::Notifications::Fanout.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def build_handle(name, id, payload)
        groups = groups_for(name)
        if groups.empty?
          NullHandle
        else
          #{body}
          Handle.new(self, name, id, instances, payload)
        end
      end
    RUBY
  when "extract"
    body = if cand
      "result = self.class.new\n keys.each { |key| result[key] = delete(key) if has_key?(key) }\n result"
    else
      "keys.each_with_object(self.class.new) { |key, result| result[key] = delete(key) if has_key?(key) }"
    end
    Hash.class_eval <<~RUBY, __FILE__, __LINE__ + 1
      def extract!(*keys)
        #{body}
      end
    RUBY
  end
end

def run_benchmark(_n, **, &block)
  lowrail_as_patch(ENV.fetch("AS"), ENV["CAND"] == "1")
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  if ENV["COUNT"] == "1"
    counts = Hash.new(0)
    tp = TracePoint.new(:call) do |t|
      counts[:build_handle_nonempty] += 1 if t.method_id == :build_handle && t.defined_class == ActiveSupport::Notifications::Fanout && !t.self.groups_for(t.binding.local_variable_get(:name)).empty?
      counts[:extract!] += 1 if t.method_id == :extract! && t.defined_class == Hash
    end
    tp.enable { 5.times(&block) }
    puts "COUNTS #{counts.transform_values { _1.fdiv(5) }}"
    return
  end
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "1"))
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations, as=#{ENV["AS"]} cand=#{ENV["CAND"]}"
end
