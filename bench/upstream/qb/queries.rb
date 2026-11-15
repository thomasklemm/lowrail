# frozen_string_literal: true

# QB1 query census: every query a request runs, by how it was built. Runs inside
# a census copy, in-process (Rack::Test, as the census):
#   bench/upstream/p_map/hx CORPUS APP bundle exec ruby THIS APP OUT_JSON
# Per workload: QB_WARMUP requests (statement caches filled), then QB_REQUESTS
# measured ones. Each SQL event is classified by the path that produced it:
#   statement_cache  StatementCache#execute (find/find_by fast path, association reader cache)
#   compiled         an Arel AST compiled by the visitor for this query (to_sql_and_binds)
#   string           SQL handed over as a string (find_by_sql, execute, select_value, ...)
# and by origin (association reader and why it skipped the cache, preloader,
# find/find_by fallback, calculations, relation loads, writes). The shape is the
# SQL with literals and bind markers folded, so two queries share a shape when
# only their values differ.
require_relative "../census/harness"
require_relative "../p_map/profile"

module QB
  WARMUP = Integer(ENV.fetch("QB_WARMUP", "5"))
  REQUESTS = Integer(ENV.fetch("QB_REQUESTS", "10"))
  REQUEST_KINDS = %i[html json form turbo].freeze

  class << self
    attr_accessor :queries, :counts, :scopes

    def stack = (Thread.current[:qb_stack] ||= [])

    def with(flag)
      stack.push(flag)
      yield
    ensure
      stack.pop
    end

    def count(key) = (counts[key] += 1 if counts)

    def kind(v) = v.nil? ? "nil" : v.is_a?(ActiveRecord::Relation) ? "a Relation" : "#{v.class.ancestors.include?(ActiveRecord::Base) ? "a record" : "a #{v.class}"}"

    def shape(sql)
      s = sql.gsub(/'(?:[^']|'')*'/, "?").gsub(/\$\d+/, "?").gsub(/\b\d+(?:\.\d+)?\b/, "?")
      s = s.gsub(/\(\s*\?(?:\s*,\s*\?)*\s*\)/, "(?+)")
      s.gsub(%r{/\*.*?\*/}, "").squeeze(" ").strip
    end

    def install
      ActiveRecord::StatementCache.prepend(Module.new do
        def execute(...) = QB.with(:statement_cache) { super }
      end)
      ActiveRecord::Base.singleton_class.prepend(Module.new do
        def find(*ids, &)
          reason = if ids.length != 1 then "several ids"
          elsif block_given? || primary_key.nil? then "block or no primary key"
          elsif scope_attributes? then current_scope ? "current_scope" : "default_scope"
          elsif ActiveRecord::StatementCache.unsupported_value?(ids.first) then "id is #{QB.kind(ids.first)}"
          end
          QB.with(:find) { QB.with([:fallback, reason]) { super } }
        end

        def find_by(*args)
          hash = args.first
          reason = if scope_attributes? then current_scope ? "current_scope" : "default_scope"
          elsif !(Hash === hash) then "not a Hash"
          else
            hash.each do |k, v|
              k = attribute_aliases[k.to_s] || k.to_s
              r = _reflect_on_association(k)
              if r && !(r.belongs_to? && !r.polymorphic?) then break(reason = "key is a #{r.macro}#{" polymorphic" if r.polymorphic?} association")
              elsif !r && !columns_hash.key?(k) then break(reason = "key is not a column")
              elsif !r && ActiveRecord::StatementCache.unsupported_value?(v.respond_to?(:id) && !v.is_a?(ActiveRecord::Relation) ? v.id : v) then break(reason = "value is #{QB.kind(v)}")
              elsif r && r.polymorphic? then break(reason = "polymorphic belongs_to key")
              end
            end
            reason
          end
          QB.with(:find_by) { QB.with([:fallback, reason]) { super } }
        end
      end)
      ActiveRecord::Associations::Association.prepend(Module.new do
        private def find_target(...)
          QB.count(:find_target)
          r = reflection
          reason = if r.has_scope? then "reflection scope"
          elsif klass.current_scope then "current_scope"
          elsif klass.has_default_scope? then "target default_scope"
          elsif r.source_reflection.active_record.has_default_scope? then "owner default_scope"
          elsif respond_to?(:disable_joins, true) && disable_joins then "disable_joins"
          end
          QB.with([:assoc, "#{r.active_record.name}##{r.name}", r.macro, reason]) { super }
        end

        private def association_scope(...)
          QB.count(:association_scope) unless @association_scope
          super
        end
      end)
      ActiveRecord::Associations::Preloader::Association::LoaderQuery.prepend(Module.new do
        def load_records_for_keys(...) = QB.with(:preload) { super }
      end)
      ActiveRecord::Relation.prepend(Module.new do
        %i[exists? calculate pluck pick ids].each do |m|
          define_method(m) { |*a, **k, &b| QB.with([:calc, m]) { super(*a, **k, &b) } }
        end
        %i[find find_by find_by! first last take].each do |m|
          define_method(m) { |*a, **k, &b| QB.with([:finder, m]) { super(*a, **k, &b) } }
        end

        def initialize_copy(...)
          QB.count(:relation_copy)
          super
        end

        def _exec_scope(*args, **kwargs, &block)
          QB.count(:exec_scope)
          rel = super
          loc = block.source_location
          tags = (rel.instance_variable_get(:@__qb_scopes) || []) + [[model.name, loc&.join(":"), args.empty? && kwargs.empty?]]
          rel.instance_variable_set(:@__qb_scopes, tags)
          rel
        end

        private def exec_main_query(...)
          QB.with([:relation, model.name, instance_variable_get(:@__qb_scopes)]) { super }
        end

        def build_where_clause(opts, *)
          QB.count(Hash === opts ? :where_hash : :where_other)
          super
        end

        private def build_arel(...)
          QB.count(:build_arel)
          super
        end
      end)
      ActiveRecord::Relation::Merger.prepend(Module.new do
        def merge(...)
          QB.count(:merge)
          super
        end
      end)
      ActiveRecord::ConnectionAdapters::DatabaseStatements.prepend(Module.new do
        def to_sql_and_binds(arel_or_sql, *rest)
          arel = arel_or_sql.respond_to?(:ast) || (Arel.arel_node?(arel_or_sql) && !(String === arel_or_sql))
          result = super
          if arel
            QB.count(:compile_arel)
            Thread.current[:qb_compiled] = result.first
          end
          result
        end
      end)
      ActiveSupport::Notifications.subscribe("sql.active_record") do |_name, _start, _finish, _id, payload|
        next unless QB.queries
        sql = payload[:sql]
        next if payload[:name] == "SCHEMA" || payload[:name] == "TRANSACTION" ||
          sql.match?(/\A\s*(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE|PRAGMA|SET )/i)
        QB.queries << QB.record(payload)
      end
    end

    def record(payload)
      sql = payload[:sql]
      flags = stack.dup
      path = if flags.include?(:statement_cache) then "statement_cache"
      elsif (compiled = Thread.current[:qb_compiled]) && sql.include?(compiled) then "compiled"
      else "string"
      end
      write = sql.match?(/\A\s*(?:INSERT|UPDATE|DELETE)/i)
      assoc = flags.reverse.find { Array === _1 && _1[0] == :assoc }
      calc = flags.reverse.find { Array === _1 && _1[0] == :calc }
      finder = flags.find { Array === _1 && _1[0] == :finder }
      rel = flags.reverse.find { Array === _1 && _1[0] == :relation }
      origin = if write then "write"
      elsif flags.include?(:preload) then "preload"
      elsif assoc && path == "statement_cache" then "association reader"
      elsif assoc then "association reader (#{assoc[3] || "eager_loading or other"})"
      elsif flags.include?(:find_by) || flags.include?(:find)
        fb = flags.find { Array === _1 && _1[0] == :fallback }
        m = flags.include?(:find_by) ? "find_by" : "find"
        path == "statement_cache" ? m : "#{m} fallback (#{fb&.[](1) || "unknown"})"
      elsif calc then "calc #{calc[1]}"
      elsif finder then "relation #{finder[1]}"
      elsif rel then rel[2] ? "relation load (named scope)" : "relation load"
      elsif payload[:name].to_s.start_with?("SolidCache") then "cache store (Solid Cache)"
      elsif sql.include?("collection_cache_key") || sql.match?(/\ASELECT COUNT\(\*\) AS "size", MAX\(/) then "collection cache_key"
      else "other (#{payload[:name]})"
      end
      scopes = rel && rel[2]
      { path: path, origin: origin, name: payload[:name], cached: !!payload[:cached], shape: shape(sql), sql: sql,
        binds: Array(payload[:type_casted_binds].is_a?(Proc) ? payload[:type_casted_binds].call : payload[:type_casted_binds]).map { |b| b = b.to_s; b.encoding == Encoding::BINARY ? b.unpack1("H*") : b },
        assoc: assoc && assoc[1], macro: assoc && assoc[2], scopes: scopes }
    end
  end

  module_function

  def run(name, output)
    raise "fresh output required" if File.exist?(output)
    QB.install
    ops = RailsCensus.workloads(name)
    ops += PMap.extra_ops(name, RailsCensus, ops)
    ops = ops.select { REQUEST_KINDS.include?(_1.kind) }
    reset = -> { RailsCensus.reset_side_effects }
    seen_app = {}
    result = ops.map do |op|
      WARMUP.times { op.call.call; reset.call }
      seen = {}
      requests = REQUESTS.times.map do |i|
        QB.queries = []
        QB.counts = Hash.new(0)
        op.call.call
        reset.call
        qs, counts = QB.queries, QB.counts
        QB.queries = QB.counts = nil
        qs.each do |q|
          q[:shape_seen_before] = seen.key?(q[:shape])
          q[:exact_seen_before] = seen_app.key?([q[:sql], q[:binds]])
        end
        qs.each { seen[_1[:shape]] = true; seen_app[[_1[:sql], _1[:binds]]] = true }
        { queries: qs, counts: counts }
      end
      { name: op.name, kind: op.kind, requests: requests }
    end
    File.write(output, JSON.generate(app: name, set: ENV["CENSUS_SET"] || "census", rails: RailsCensus.rails_sha,
      adapter: ActiveRecord::Base.connection_db_config.adapter,
      prepared_statements: ActiveRecord::Base.with_connection(&:prepared_statements), warmup: WARMUP, workloads: result))
    puts JSON.generate(app: name, workloads: result.size, queries: result.sum { |w| w[:requests].sum { _1[:queries].size } })
  end
end

if $PROGRAM_NAME == __FILE__
  name, output = ARGV
  RailsCensus.boot(name)
  QB.run(name, output)
end
