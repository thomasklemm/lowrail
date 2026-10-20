# frozen_string_literal: true

# Seeded relation grammar, exact differential and deletion minimizer. No app
# dependencies: Ruby 3.4+, Rails 8.1.4, sqlite3; optional disposable Postgres DB.
require "json"
require "open3"
require "rbconfig"

module AREquivalence
  BASES = ["EqPost.all", "EqWriter.find(1).posts", "EqWriter.find(2).preferred_posts",
    "EqWriter.find(1).preferred_posts", "EqWriter.all", "EqAsset.all",
    "EqSpecialAsset.all", "EqDefaultPost.all", "EqNote.all", "EqWriter.find(1).empty_posts",
    "EqWriter.find(2).zero_posts", "EqWriter.find(1).selected_posts", "EqWriter.find(2).preloaded_posts",
    "EqWriter.find(1).live_posts", "EqWriter.find(1).writer_notes"].freeze
  OPS = ["where(id: [1, 3, 5])", "where(id: 2..5)", "where(id: 2...5)",
    "where(title: nil)", "where(published: true)", "where.not(id: [2, 4])",
    "where(['id > ?', 2])", "or(%MODEL%.where(id: 5))", "merge(%MODEL%.where(id: 1..4))",
    "joins(:writer)", "left_joins(:notes)", "includes(:writer)", "preload(:notes)",
    "eager_load(:writer)", "order(id: :desc)", "reorder(:id)", "limit(2)", "limit(0)",
    "offset(1)", "select(:id, :writer_id, :title)", "distinct", "group(:writer_id)",
    "having('COUNT(*) > 1')", "unscope(:where, :order)", "none", "published_first",
    "where(status: :live)", "where(slug: 'Beta')", "where(settings: { 'x' => 1 })",
    "includes(posts: :notes)", "preload(:assets)", "joins(:writer_notes)",
    "preload(:preferred_posts)", "preload(:notable)", "where(id: [])"].freeze
  ENDS = %w[to_a first last take find_by(id:3) exists?(3) count pluck(:id,:title) ids].freeze
  PHASES = %w[boot default_scope column scoping].freeze

  def self.cases(seed, n)
    random = Random.new(seed)
    # Guaranteed terminals and individual grammar productions, followed by
    # bounded random compositions; invalid combinations are compared too.
    directed = BASES.flat_map { |base| ENDS.map { { "base" => base, "ops" => [], "end" => _1 } } }
    directed += OPS.flat_map { |op| ENDS.map { { "base" => BASES.first, "ops" => [op], "end" => _1 } } }
    ["preload(posts: :notes)", "includes(:posts, :same_posts)", "preload(:writer_notes)", "preload(:assets)"].each do |op|
      ENDS.each { directed << { "base" => "EqWriter.all", "ops" => [op], "end" => _1 } }
    end
    directed << { "base" => "EqWriter.all", "ops" => [], "end" => "first.first_post" }
    directed + Array.new(n) do
      { "base" => BASES.sample(random: random), "ops" => Array.new(random.rand(1..6)) { OPS.sample(random: random) },
        "end" => ENDS.sample(random: random), "cache" => random.rand(4).zero? }
    end
  end

  def self.schema
    gem "activerecord", ENV.fetch("AR_EQ_RAILS", "8.1.4")
    require "active_record"
    require_relative "ar_equivalence_runtime"
    Object.const_set(:Rails, Module.new) unless defined?(Rails)
    Rails.define_singleton_method(:version) { ActiveRecord::VERSION::STRING }
    Lowrail::AR.install if Lowrail.enabled?
    url = ENV["AR_EQ_DATABASE_URL"]
    ActiveRecord::Base.establish_connection(url || { adapter: "sqlite3", database: ":memory:", prepared_statements: ENV["AR_EQ_PREPARED"] != "0" })
    ActiveRecord::Schema.verbose = false
    ActiveRecord::Schema.define do
      create_table(:eq_writers, force: true) { |t| t.string :name }
      create_table(:eq_posts, force: true) do |t|
        t.integer :writer_id; t.string :title; t.boolean :published; t.integer :status
        t.text :settings; t.string :slug
      end
      create_table(:eq_notes, force: true) { |t| t.integer :post_id; t.string :body }
      create_table(:eq_assets, force: true) { |t| t.string :type; t.integer :notable_id; t.string :notable_type }
    end
    require_relative "ar_equivalence_models"
    3.times { |i| EqWriter.create!(id: i + 1, name: "writer-#{i}") }
    7.times do |i|
      EqPost.create!(id: i + 1, writer_id: i % 3 + 1, title: i == 2 ? nil : "title-#{7 - i}",
        published: i.even?, status: i % 2, settings: { "x" => i % 3 }, slug: i.even? ? "Beta" : "alpha")
      (i % 3).times { |j| EqNote.create!(post_id: i + 1, body: "note-#{i}-#{j}") }
    end
    EqSpecialAsset.create!(notable: EqPost.find(2))
    EqAsset.create!(notable: EqWriter.find(1))
    # Warm schema outside the observation window, as app boot/build would.
    [EqPost, EqWriter, EqNote, EqAsset, EqSpecialAsset, EqDefaultPost].each { _1.columns_hash; _1.attribute_types }
  end

  def self.value(object, depth = 0)
    case object
    when ActiveRecord::Base
      loaded = object.class.reflect_on_all_associations.filter_map do |r|
        association = object.association(r.name)
        [r.name, value(association.target, depth + 1)] if association.loaded? && depth < 2
      end
      [object.class.name, object.attributes, loaded]
    when Array then object.map { value(_1, depth) }
    when Hash then object.map { [value(_1, depth), value(_2, depth)] }
    else object
    end
  end

  def self.execute(spec, phase)
    events = []
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if payload[:name] == "SCHEMA"
      events << [payload[:name], payload[:sql], payload[:binds].map { Lowrail::ARShadow.bind(_1) }, !!payload[:cached]]
    end
    before = Lowrail::Stats.unit_hits.dup
    result = begin
      run = lambda do
        relation = eval(spec.fetch("base"), TOPLEVEL_BINDING)
        model = relation.model.name
        spec.fetch("ops").each { relation = relation.instance_eval("self." + _1.gsub("%MODEL%", model)) }
        value(relation.instance_eval("self." + spec.fetch("end")))
      end
      body = -> { spec["cache"] ? ActiveRecord::Base.cache { [run.call, run.call] } : run.call }
      output = phase == "scoping" ? EqPost.where(published: false).scoping(all_queries: true, &body) : body.call
      { "value" => output }
    rescue StandardError => e
      { "exception" => [e.class.name, e.message.gsub(/0x[0-9a-f]+/, "0x?")] }
    end
    hits = Lowrail::Stats.unit_hits.to_h { |id, count| [id, count - before.fetch(id, 0)] }
    [result.merge("sql" => events), hits]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  def self.worker(phase, seed, n, single = nil)
    schema
    built = Lowrail::AREquivalenceRuntime.build
    # Warm real SQL/builder/preload caches before each independent mutation.
    execute({ "base" => BASES[2], "ops" => [], "end" => "to_a" }, "boot")
    execute({ "base" => BASES[0], "ops" => ["preload(:notes)"], "end" => "to_a" }, "boot")
    case phase
    when "default_scope" then EqPost.send(:default_scope, -> { where(published: false) })
    when "column"
      EqPost.connection_pool.with_connection do |connection|
        options = connection.adapter_name == "PostgreSQL" ? { using: "published::integer" } : {}
        connection.change_column(:eq_posts, :published, :integer, **options)
      end
      EqPost.reset_column_information
    end
    results = (single ? [JSON.parse(single)] : cases(seed, n)).map { execute(_1, phase) }
    puts JSON.generate({ "results" => results, "units" => built[:manifest].units.map { [_1["id"], _1["pass"]] }.to_h,
      "ledger" => built[:ledger], "shadow" => Lowrail::ARShadow.counts, "shadow_mismatches" => Lowrail::ARShadow.mismatches.size,
      "adapter" => ActiveRecord::Base.connection_pool.db_config.adapter, "rails" => Rails.version })
  end

  def self.run_worker(mode, phase, seed, n, single = nil)
    out, err, status = Open3.capture3({ "LOWRAIL" => mode, "LOWRAIL_SHADOW" => ENV.fetch("LOWRAIL_SHADOW", "strict") },
      RbConfig.ruby, "-I#{File.expand_path('../gem/lib', __dir__)}", __FILE__, "--worker", phase, seed.to_s, n.to_s, *[single && JSON.generate(single)].compact)
    raise "worker #{mode}/#{phase} failed: #{err}\n#{out[-2000..]}" unless status.success?
    JSON.parse(out.lines.last)
  end

  def self.different?(spec, phase, seed)
    off, on = %w[0 1].map { run_worker(_1, phase, seed, 0, spec).fetch("results").first.first }
    off != on
  end

  def self.minimize(spec, phase, seed)
    spec = Marshal.load(Marshal.dump(spec))
    # 1-minimal for operation deletion. Reproduction always starts a fresh
    # process so prior guard invalidation/cache state cannot hide a failure.
    loop do
      index = spec["ops"].each_index.find do |i|
        candidate = spec.merge("ops" => spec["ops"].each_with_index.reject { |_, j| i == j }.map(&:first))
        if different?(candidate, phase, seed)
          spec = candidate
          true
        end
      end
      break unless index
    end
    spec
  end

  def self.main
    seed = Integer(ENV.fetch("SEED", "41231"))
    n = Integer(ENV.fetch("CHAINS", "500"))
    report = { "seed" => seed, "random_chains_per_phase" => n, "phases" => {}, "bugs" => [] }
    ENV.fetch("PHASES", PHASES.join(",")).split(",").each do |phase|
      off, on = %w[0 1].map { run_worker(_1, phase, seed, n) }
      counters = Hash.new(0)
      on["results"].each_with_index do |(actual, hits), i|
        expected = off.fetch("results")[i].first
        passes = hits.filter_map { |id, count| on["units"][id] if count > 0 }.uniq
        passes.each { counters[_1] += 1 }
        counters["no_sql_plan_hit"] += 1 if (passes & %w[active_record/ar_plans active_record/preload_plans]).empty?
        counters["exceptions"] += 1 if expected.key?("exception")
        next if expected == actual
        spec = cases(seed, n)[i]
        isolated = different?(spec, phase, seed)
        minimal = isolated ? minimize(spec, phase, seed) : nil
        report["bugs"] << { "phase" => phase, "index" => i, "case" => spec, "minimal" => minimal,
          "requires_prefix" => !isolated,
          "expected" => expected, "actual" => actual }
      end
      report["phases"][phase] = { "chains" => on["results"].size,
        "queries" => off["results"].sum { _1.first.fetch("sql").size }, "coverage" => counters, "shadow" => on["shadow"],
        "adapter" => on["adapter"], "rails" => on["rails"], "shadow_mismatches" => on["shadow_mismatches"],
        "ledger" => on["ledger"].group_by { _1["pass"] }.transform_values { |entries| entries.map { [_1["method"] || _1["file"], _1["outcome"]] } } }
      warn "#{phase}: #{on['results'].size} chains; #{counters}; #{report['bugs'].size} mismatches"
    end
    puts JSON.pretty_generate(report)
    exit 1 unless report["bugs"].empty?
  end
end

if $PROGRAM_NAME == __FILE__
  ARGV.first == "--worker" ? AREquivalence.worker(ARGV[1], Integer(ARGV[2]), Integer(ARGV[3]), ARGV[4]) : AREquivalence.main
end
