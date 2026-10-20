# frozen_string_literal: true

require "json"

# Keep the component runner's duplicate-safe comparison usable independently of
# the checkout/dependency orchestrator. No runtime instrumentation lives here.
module RailsSuiteReport
  def self.read(path)
    JSON.parse(File.read(path + ".shadow.json")).fetch("outcomes")
  end

  def self.compare(off_path, on_path, control_path = nil, repeat_path = nil)
    off, on = [off_path, on_path].map { read(_1) }
    control = control_path && read(control_path)
    repeat = repeat_path && read(repeat_path)
    keys = off.keys | on.keys
    # Observation order is incidental when printed identities collide. Compare
    # multisets, not sets (which would lose an extra pass/failure).
    canonical = ->(entries) { entries&.sort_by { JSON.generate(_1) } }
    different = ->(a, b, key) { canonical.call(a[key]) != canonical.call(b[key]) }
    unstable = control ? (keys | control.keys).select { different.call(off, control, _1) } : []
    changed = keys.select { different.call(off, on, _1) }
    transient = repeat ? changed.select { !different.call(off, repeat, _1) || different.call(on, repeat, _1) } : []
    differences = changed - unstable - transient
    { "observations" => [off, on].map { _1.values.sum(&:size) },
      "identical" => (keys - changed).sum { off.fetch(_1, []).size },
      "outcomes" => [off, on].map { _1.values.flatten.group_by { |entry| entry.fetch("result") }.transform_values(&:size) },
      "unstable" => unstable, "transient" => transient,
      "differences" => differences.to_h { [_1, { "off" => off[_1], "on" => on[_1] }] } }
  end

  module Observations
    def record(result)
      super
      key = "#{result.respond_to?(:klass) ? result.klass : result.class.name}##{result.name}"
      entry = { "result" => Lowrail::Minitest::Reporter.result_of(result) }
      entry["failure"] = Lowrail::Minitest::Reporter.describe(result.failures.first) unless result.failures.empty?
      (@observations ||= Hash.new { |hash, name| hash[name] = [] })[key] << entry
      (@locations ||= {})[key] = result.source_location if result.respond_to?(:source_location)
    end

    def report
      super
      Lowrail.write_json(ENV.fetch("LOWRAIL_OUTCOMES") + ".shadow.json", {
        "checks" => defined?(Lowrail::ARShadow) ? Lowrail::ARShadow.counts : {},
        "mismatches" => defined?(Lowrail::ARShadow) ? Lowrail::ARShadow.mismatches : [],
        "outcomes" => @observations || {}, "locations" => @locations || {},
        "hooks" => { "guard" => defined?(Lowrail::Guard) && Lowrail::Guard.installed?,
          "loader" => defined?(Lowrail::Loader) && Lowrail::Loader.installed?,
          "templates" => !!(defined?(ActionView::Template) && defined?(Lowrail::Templates::CompiledSource) &&
            ActionView::Template < Lowrail::Templates::CompiledSource),
          "ar_epoch_requested" => !!defined?(Lowrail::AR),
          "ar_epoch" => !!(defined?(Lowrail::AR) && Lowrail::AR.installed?) } })
    end
  end
end
