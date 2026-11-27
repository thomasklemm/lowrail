# frozen_string_literal: true

# Census 12 hot clusters: self instructions of the methods that do one piece of
# work, as a share of each whole workload (cpu_harness method self cost, Rails
# and gem frames). Mean over all JIT-flat workloads, reach (>= 0.1%), max.
#   ruby clusters.rb DIR LABEL MODE
require "json"

CLUSTERS = {
  "query cache key hashing" => /QueryCache::Store#compute_if_absent|Relation::QueryAttribute#hash|ActiveModel::Attribute#hash|ActiveModel::Type::Value#hash/,
  "IsolatedExecutionState reads" => /IsolatedExecutionState\.(\[\]|context)\z/,
  "AR connection lookup" => /ConnectionHandling#(connection_specification_name|connection_pool)|ActiveRecord::Base\.(connected_to_stack|current_role|current_shard|connection_handler|current_preventing_writes)|ConnectionHandler#retrieve_connection_pool|ConnectionPool::LeaseRegistry#lease|WeakKeyMap#\[\]/,
  "InheritableOptions parent reads" => /InheritableOptions#initialize|OrderedOptions#(\[\]|method_missing|_get)\z/,
  "filtered parameters" => /ActiveSupport::ParameterFilter#/,
  "notifications fan-out" => /Notifications::(Fanout|FanoutIteration|Instrumenter|Fanout::Handle|Fanout::BaseGroup)/,
  "CSRF token masking" => /RequestForgeryProtection#(csrf_token_hmac|xor_byte_strings|mask_token|per_form_csrf_token|global_csrf_token|real_csrf_token|unmask_token|compare_with_real_token)/,
  "tag attribute building" => /TagBuilder#(tag_options|append_tag_option|tag_option|boolean_tag_option)|ERB::Util\.xml_name_escape|ERBUtil#html_escape/,
  "env_config merge (build_request)" => /Rails::(Engine|Application)#build_request/,
  "inertia_rails config (Hash#extract!)" => /Hash#extract!/,
  "cache_quoted_name (since census 11)" => /Quoting::ClassMethods#cache_quoted_name/,
}.freeze

dir, label, mode = ARGV
workloads = Dir["#{dir}/#{label}/*-#{mode}.json"].sort.flat_map do |path|
  run = JSON.parse(File.read(path))
  run["workloads"].select { _1.fetch("jit_flat", true) }.map { [run["app"], _1] }
end
n = workloads.size
puts "# #{label} #{mode}: #{n} workloads; cluster self Ir as % of each workload"
CLUSTERS.each do |name, re|
  shares = workloads.map do |app, w|
    [app, w["workload"], w["methods"].select { re.match?(_1["method"]) }.sum { _1["self_ir_per_op"] } / w["ir_per_op"]]
  end
  mean = shares.sum { _3 } / n
  reach = shares.count { _3 >= 0.001 }
  app, wl, max = shares.max_by { _3 }
  apps = shares.select { _3 >= 0.001 }.map(&:first).uniq.size
  printf("%-38s mean %6.3f%%  reach %2d/%d (%d apps)  >=1%%: %2d  max %6.3f%% %s %s  score %.3f\n", name, 100 * mean, reach, n, apps,
    shares.count { _3 >= 0.01 }, 100 * max, app, wl, 100 * mean * reach / n)
end
