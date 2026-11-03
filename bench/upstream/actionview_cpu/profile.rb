# frozen_string_literal: true

# Sampling CPU profile of a block with stackprof (raw stacks). Used by every
# driver in this directory.
#
#   AvCpu.profile(label, out_dir, rails_dir:, app_dir:) { workload }
#
# Writes OUT_DIR/LABEL.json: { label, ruby, yjit, mode, interval_us, samples,
# frames: { id => [name, site, line] }, stacks: [[count, id, ...]] } with each
# distinct stack (outermost first) once. rank.rb aggregates them.
# AVCPU_MODE (wall, default here; cpu) and AVCPU_INTERVAL_US choose the sampler.
require "json"
require "fileutils"
require "stackprof"

module AvCpu
  INTERVAL_US = Integer(ENV.fetch("AVCPU_INTERVAL_US", "250"))
  MODE = ENV.fetch("AVCPU_MODE", "wall").to_sym

  module_function

  # Paths relative to Rails, the app, a gem or Ruby's lib; "<cfunc>" for C.
  def site(file, rails_dir, app_dir)
    return "<cfunc>" if file.nil? || file.empty? || file == "<cfunc>"
    if rails_dir && file.start_with?(rails_dir + "/")
      "RAILS/" + file.delete_prefix(rails_dir + "/")
    elsif app_dir && file.start_with?(app_dir + "/")
      "APP/" + file.delete_prefix(app_dir + "/")
    elsif file.include?("/gems/")
      "GEM/" + file.split("/gems/").last
    elsif file.start_with?(RbConfig::CONFIG.fetch("rubylibdir") + "/")
      "RUBY/" + file.delete_prefix(RbConfig::CONFIG.fetch("rubylibdir") + "/")
    else
      file
    end
  end

  def profile(label, out_dir, rails_dir:, app_dir: nil, &block)
    GC.start
    result = StackProf.run(mode: MODE, interval: INTERVAL_US, raw: true, &block)
    raw = result.fetch(:raw)
    stacks = Hash.new(0)
    samples = 0
    i = 0
    while i < raw.size
      len = raw[i]
      weight = raw[i + 1 + len]
      stacks[raw[i + 1, len]] += weight
      samples += weight
      i += len + 2
    end
    frames = result.fetch(:frames).to_h do |id, f|
      [id.to_s, [f[:name], site(f[:file], rails_dir, app_dir), f[:line]]]
    end
    data = { "label" => label, "ruby" => RUBY_DESCRIPTION, "yjit" => !!(defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?),
             "mode" => MODE.to_s, "interval_us" => INTERVAL_US, "samples" => samples, "frames" => frames,
             "stacks" => stacks.map { |stack, n| [n, *stack] } }
    FileUtils.mkdir_p(out_dir)
    File.write(File.join(out_dir, "#{label}.json"), JSON.generate(data))
    warn "#{label}: #{samples} samples"
    data
  end
end
