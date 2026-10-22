# frozen_string_literal: true

# Consolidate the pinned Y2 experiment receipts, not an application benchmark.
# ruby bench/experiments/yjit_exits_report.rb /tmp/y2 docs/yjit-exits.json
require "json"
require "digest"

data = File.expand_path(ARGV.fetch(0))
read = ->(name) { JSON.parse(File.read(File.join(data, name))) }
receipt = ->(name) { {sha256: Digest::SHA256.file(File.join(data, name)).hexdigest, text: File.read(File.join(data, name))} }

compact = nil
compact = lambda do |value|
  case value
  when Array then value.map { compact.call(_1) }
  when Hash
    value.to_h do |key, child|
      if key == "jit_delta" && child
        child = child.reject do |name, count|
          name.start_with?("Y2|") && (count.zero? || (name.start_with?("Y2|num_") && !name.start_with?("Y2|num_send_dynamic|")))
        end
      end
      child = child.reject { |name, _| name.start_with?("Y2|") } if key == "jit_before" && child
      [key, compact.call(child)]
    end
  else value
  end
end

cohorts = %w[blog-census fizzy-census blog-patch fizzy-patch blog-v2-base fizzy-v2-base blog-v2-patch fizzy-v2-patch blog-v3-base fizzy-v3-base blog-v3-patch fizzy-v3-patch].to_h do |label|
  [label, compact.call(read.call("#{label}/result.json"))]
end

%w[blog fizzy].each do |app|
  rows = cohorts.select { |name, _| name.start_with?(app) }.values.flat_map { _1.fetch("workers") }
  raise "cross-cohort exact mismatch: #{app}" unless rows.select { _1["phase"] == "exact" }.map { _1.fetch("exact") }.uniq.size == 1
  raise "cross-cohort sequence mismatch: #{app}" unless rows.select { _1["phase"] == "census" }.map { |r| r.fetch("windows").map { _1.fetch("response_sequence_sha256") } }.uniq.size == 1
end

reconciliation = {}
cohorts.each do |label, cohort|
  cohort.fetch("workers").select { _1["arm"] == "on" && %w[census stats].include?(_1["phase"]) }.each do |row|
    (row["windows"] || [row]).each do |window|
      stats = window.fetch("jit_delta")
      sites = stats.select { |name, _| name.start_with?("Y2|") }
      next if sites.empty? # Clean patch binaries deliberately have no site instrumentation.
      raise "unregistered site" if sites.any? { |name, count| name.include?("|unregistered") && count.positive? }
      by_reason = sites.group_by { |name, _| name.split("|", 3).fetch(1) }.transform_values { _1.sum { |_, count| count } }
      by_reason.each do |reason, count|
        next unless stats.key?(reason)
        raise "site/global mismatch: #{label} #{reason}" unless count == stats.fetch(reason)
      end
      exits = by_reason.select { |reason, _| reason.start_with?("exit_") }.values.sum
      raise "exit census mismatch" unless exits == stats.fetch("side_exit_count")
      if label.match?(/v[23]/)
        fallbacks = sites.select { |name, _| name.start_with?("Y2|fallback_") }
        final_sites = fallbacks.group_by { |name, _| name.split("|", 3).last }.transform_values { _1.sum { |_, count| count } }
        dynamic_sites = sites.select { |name, _| name.start_with?("Y2|num_send_dynamic|") }.to_h { |name, count| [name.split("|", 3).last, count] }
        raise "final fallback site mismatch" unless final_sites == dynamic_sites
        raise "final fallback global mismatch" unless fallbacks.values.sum == stats.fetch("num_send_dynamic")
        raise "unclassified fallback" if fallbacks.any? { |name, _| name.start_with?("Y2|fallback_unclassified|") }
        raise "invalidation census mismatch" unless by_reason.fetch("invalidate_constant_ic_fill", 0) == stats.fetch("invalidation_count")
      end
      if label.include?("v3")
        attempts = by_reason.select { |reason, _| reason.start_with?("attempt_") }
        raise "attempt census mismatch" unless attempts.values.sum == stats.fetch("y2_send_dynamic_attempts")
        attempts.each do |reason, count|
          name = reason.delete_prefix("attempt_")
          raise "attempt/refusal mismatch: #{name}" unless count == stats.fetch(name)
        end
      end
      reconciliation[[label, row["phase"], window["seed"]].compact.join("/")] = {
        requests: window.fetch("requests"), reasons_checked: by_reason.count { |reason, _| stats.key?(reason) },
        side_exits: exits, completed_dynamic_sends: stats.fetch("num_send_dynamic"),
        dynamic_send_attempts: stats["y2_send_dynamic_attempts"],
        final_fallbacks_completed: label.match?(/v[23]/) ? stats.select { |name, _| name.start_with?("Y2|fallback_") }.values.sum : nil,
        invalidations: stats.fetch("invalidation_count"), unregistered: 0
      }
    end
  end
end

rankings = %w[attempt fallback].to_h do |kind|
  [kind, %w[blog fizzy].to_h do |app|
    [app, %w[base patch].to_h do |arm|
      cohort = cohorts.fetch("#{app}-v3-#{arm}")
      row = cohort.fetch("workers").find { _1["arm"] == "on" && _1["phase"] == "stats" }
      sites = row.fetch("jit_delta").select { |name, count| name.start_with?("Y2|#{kind}_") && count.positive? }
      [arm, sites.group_by { |name, _| name.split("|", 3).fetch(1).delete_prefix("#{kind}_") }.map do |reason, entries|
        {reason: reason, per_request: entries.sum { |_, n| n }.fdiv(row.fetch("requests")),
          sites: entries.sort_by { |_, n| -n }.to_h.transform_values { _1.fdiv(row.fetch("requests")) }}
      end.sort_by { -_1.fetch(:per_request) }]
    end]
  end]
end

ir = %w[interpreter yjit zjit].to_h do |mode|
  [mode, %w[base off_b patch].to_h do |arm|
    [arm, [0, 5_000, 10_000].to_h do |n|
      prefix = mode == "interpreter" ? "ir" : "#{mode}-ir"
      name = "#{prefix}-#{arm}-#{n}"
      dump = "#{name}.1" # Client-request dump, NOT the process-termination summary.
      count = Integer(File.read(File.join(data, dump)).match(/^summary: (\d+)$/).captures.fetch(0))
      [n, {ir: count, dump_sha256: Digest::SHA256.file(File.join(data, dump)).hexdigest, output: read.call("#{name}.json")}]
    end]
  end]
end
%w[interpreter zjit].each do |mode|
  raise "#{mode} Ir changed" unless ir.fetch(mode).values.map { |rows| rows.values.map { _1.fetch(:ir) } }.uniq.size == 1
end
raise "YJIT A/A Ir changed" unless ir.fetch("yjit").values_at("base", "off_b").map { |rows| rows.values.map { _1.fetch(:ir) } }.uniq.size == 1

z3 = JSON.parse(File.read("/tmp/y2-z3/docs/zjit-fallbacks-2.json"))
reproduction = z3.fetch("reproduction").slice("bundles", "policies", "seed_preparation_source", "seed_preparation_source_origin")
reproduction["prepare_wrapper"] = File.read(File.join(data, "prepare.sh"))
reproduction["residual_receiver_probe"] = File.read(File.join(data, "residual_probe.rb"))
reproduction["census_patch"] = File.read(File.join(data, "census-v3.patch"))
reproduction["completion_census_patch"] = File.read(File.join(data, "census-v2.patch"))
reproduction["original_census_patch"] = File.read(File.join(data, "census.patch"))

tests = %w[yjit-check.log ruby-tests-interpreter.log ruby-tests-yjit.log ruby-tests-zjit.log regression-base.log].to_h { [_1, receipt.call(_1)] }
semantics = Dir[File.join(data, "semantics", "*.json")].sort.to_h { |path| [File.basename(path, ".json"), JSON.parse(File.read(path))] }
%w[interpreter yjit zjit].each do |mode|
  raise "#{mode} semantic mismatch" unless semantics.fetch("base-#{mode}") == semantics.fetch("patch-#{mode}")
end
residual_receivers = %w[blog fizzy].to_h do |app|
  text = File.read(File.join(data, "#{app}-residual.json"))
  [app, JSON.parse(text[text.index(/^\[/)..])]
end
micro = read.call("micro.json")
raise "wrong micro cohort size" unless micro.fetch("workers").size == 90
micro.fetch("summary").each do |mode, comparisons|
  raise "A/A excludes zero: #{mode}" unless comparisons.fetch("off_b").fetch("ci95_pct").then { _1.first <= 0 && _1.last >= 0 }
  raise "resolved regression: #{mode}" if comparisons.fetch("on").fetch("ci95_pct").first > 0
end
raise "no YJIT gain" unless micro.fetch("summary").fetch("yjit").fetch("on").fetch("ci95_pct").last < 0

report = {
  scope: "Y2: finite Rails-request YJIT census and one Class/Module super exemption; fork-only handoff, no whole-request speed claim",
  date: "2026-10-22",
  ruby_base: "8ff4ae135d438314090f0dc23916601ef9c444d5",
  ruby_patch: "df0fa8fc9de28e5e39220e58798d549e4ac54e32",
  ruby_repository: "https://github.com/thomasklemm/ruby", branch: "thomasklemm/yjit-exits",
  lowrail_base: "9afd2c0beec06fd07edcb39532757c91775c25df",
  method_source: "85d877edaaf9713768099b6de77e4d6beb8bb0a8",
  native_harness: {repository: "https://github.com/thomasklemm/lowrail", commit: "6510cd2f2cd4384fcf648c638f5f720d00c8d9c8"},
  environment: {
    configure: "./configure --prefix=/tmp/y2-ruby --enable-yjit=stats --enable-zjit=stats --disable-install-doc",
    build: "make -j4; make install", bootstrap_ruby: "4.0.7", gcc: "12.2.0", rustc: "1.99.1", valgrind: "3.19.0", cpu: 2,
    warmup: 1200, requests_per_seed: 300, seeds: [0, 1], bundler: "4.0.20",
    binaries: %w[base-ruby patch-ruby census-ruby census-v2-base-ruby census-v2-patch-ruby census-v3-base-ruby census-v3-patch-ruby].to_h { [_1, Digest::SHA256.file(File.join(data, _1)).hexdigest] },
    app_sources: {blog: "https://github.com/rubys/roundhouse@bb90df2514f80817f98d89848dd0a6baa8df20a9:fixtures/real-blog", fizzy: "6f1d200316ec3bae91d32c557d88647300807ee9"}
  },
  cohorts: cohorts, final_fallback_rankings: rankings.fetch("attempt"), completed_dispatch_rankings: rankings.fetch("fallback"), site_global_reconciliation: reconciliation,
  micro: micro, micro_untimed: %w[base patch].to_h { [_1, read.call("micro-stats-#{_1}.json")] },
  ir: ir, tests: tests, semantic_matrix: semantics, residual_receivers: residual_receivers,
  upstream_status: {
    open_pr_count: 763, open_pr_dump_sha256: Digest::SHA256.file(File.join(data, "open-prs.jsonl")).hexdigest,
    open_prs: File.readlines(File.join(data, "open-prs.jsonl")).map { JSON.parse(_1).except("body") },
    focused_queries: ["repo:ruby/ruby is:pr YJIT super singleton", "repo:ruby/ruby is:pr invokesuper_singleton_class", "repo:ruby/ruby is:pr YJIT singleton module"],
    result: "No matching YJIT Class/Module super exemption found. #18326/#19351/#19484 are ZJIT; #6920/#17629 concern VM argument/dispatch mechanics, not this YJIT exemption. #6674 is Module#===. bugs.ruby-lang.org #20209 explains the retained ordinary-object refusal; #20195/#20012 are keyword correctness history; #22309 concerns module/refinement super semantics; #22116 is a closed define_method/super crash. None establishes coverage of this exemption."
  },
  reproduction: reproduction,
  caveats: [
    "Stock num_send_dynamic increments AFTER the VM call and misses nonlocal departures. attempt_* counters count final dispatches before the call; fallback_* counters count normal returns, reconciling to the native global per site. Attempt totals also reconcile to an independent global and native refusal reasons. No unclassified sites. The earlier overlap hypothesis for the blog keyword-splat discrepancy was incorrect; Fizzy send_bpp_dispatch instead counts successful proxy dispatch, not fallback.",
    "Zero site deltas and successful/general num_* site counters are omitted, except num_send_dynamic. All native global counters are retained; site-level jit_before maps are omitted.",
    "Unchanged Fizzy A/A processes show two dispatch profiles: 1333 or 1302 dynamic sends/request (megamorphic 245 or 216 plus two other sends). Same-profile patch removes exactly 284 in both; do not attribute profile variation to this patch or instrumentation.",
    "Seeded census adds entropy wrappers and first-window compilation/constant-IC fills. Preserve both windows; unseeded stats are separate.",
    "Ordinary singleton objects remain refused. Class/Module exemption matches existing ordinary-send policy; named Rails constants are already rooted. This is NOT a universal collectability guarantee for anonymous classes/modules.",
    "ZJIT ordinary-object WeakRef retention occurs identically in both arms; separately observed, not changed or fixed by this YJIT patch.",
    "One timing cohort retained, not rerun for green. Interpreter/ZJIT apparent wall gains are not causal claims. Fixed-seed interpreter and ZJIT Ir are exactly identical.",
    "No Campfire (third bundle/assets/state not cheap), full Rails suite/lowrail verify, full Ruby suite/ruby-spec, AArch64 or whole-request YJIT-flat throughput claim."
  ]
}
File.write(ARGV.fetch(1), JSON.pretty_generate(report) + "\n")
puts "#{reconciliation.size} windows reconcile; exact responses/sequences and 6 semantic arms match; 90 timing rows retained; interpreter/ZJIT Ir identical; YJIT A/A Ir identical"
