# frozen_string_literal: true

# Summarize a raw stackprof profile by area (gem or app) and by frame.
#   ruby bench/profile_summary.rb profile.json [APP_ROOT] [TOP]
# "self" = samples where the frame is on top; "total" = samples where it is
# anywhere on the stack (counted once per sample).

require "json"

module ProfileSummary
  module_function

  def area(file, app_root)
    return "erb(app)" if file.include?("/app/views/")
    return "app" if app_root && file.start_with?(app_root) && !file.include?("/vendor/")
    # Git-sourced Rails has one bundler checkout, not one path per component.
    return Regexp.last_match(1) if file =~ %r{/rails-[^/]+/(action[a-z]+|active[a-z]+|railties)/lib/}
    return Regexp.last_match(1) if file =~ %r{/gems/([a-z_\-]+?)-\d[^/]*/}
    return "ruby-stdlib" if file.include?("/lib/ruby/4") || file.include?("/lib/ruby/3")
    file.empty? ? "(native)" : "other"
  end

  def counts(prof, app_root)
    frames = prof.fetch("frames")
    raw = prof.fetch("raw", []) # StackProf omits raw when no samples landed.
    result = { samples: 0, self: Hash.new(0), inclusive: Hash.new(0),
      self_by_area: Hash.new(0), total_by_area: Hash.new(0),
      self_by_file: Hash.new(0), inclusive_by_file: Hash.new(0) }
    i = 0
    while i < raw.length
      len = raw[i]
      stack = raw[i + 1, len]
      count = raw[i + 1 + len]
      i += len + 2
      result[:samples] += count
      next if stack.empty?
      result[:self][stack.last] += count
      result[:self_by_file][frames.fetch(stack.last.to_s)["file"].to_s] += count
      stack.uniq.each { |id| result[:inclusive][id] += count }
      entries = stack.map { frames.fetch(_1.to_s) }
      entries.map { _1["file"].to_s }.uniq.each { result[:inclusive_by_file][_1] += count }
      # Charge native self to its Ruby caller's area, retaining native frames.
      ruby_entries = entries.select { _1["line"].to_i > 0 || _1["lines"]&.any? }
      caller = ruby_entries.last
      result[:self_by_area][caller ? area(caller["file"].to_s, app_root) : "(native)"] += count
      ruby_entries.map { area(_1["file"].to_s, app_root) }.uniq.each { result[:total_by_area][_1] += count }
    end
    result
  end

  def print(prof, app_root, top)
    frames = prof.fetch("frames")
    result = counts(prof, app_root)
    total = result.fetch(:samples)
    pct = ->(n) { format("%5.1f%%", total.positive? ? 100.0 * n / total : 0) }
    puts "samples: #{total}"
    puts "\nby area (self / total):"
    own, inclusive = result.values_at(:self_by_area, :total_by_area)
    own.keys.union(inclusive.keys).sort_by { -own[_1] }.each do |a|
      puts format("  %-28s %s  %s", a, pct.(own[a]), pct.(inclusive[a]))
    end
    label = lambda do |id|
      frame = frames.fetch(id.to_s)
      ruby = frame["line"].to_i > 0 || frame["lines"]&.any?
      ruby ? "#{frame['name']} (#{area(frame['file'].to_s, app_root)}:#{frame['line'] || 'generated'})" : "#{frame['name']} (C)"
    end
    { self: "self", inclusive: "total" }.each do |key, title|
      puts "\ntop #{top} frames by #{title}:"
      result.fetch(key).sort_by { -_2 }.first(top).each { |id, n| puts "  #{pct.(n)}  #{label.(id)}" }
    end
  end
end

if $PROGRAM_NAME == __FILE__
  path, app_root, top = ARGV
  ProfileSummary.print(JSON.parse(File.read(path)), app_root, Integer(top || 25))
end
