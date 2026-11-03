# frozen_string_literal: true

# Summarize ZJIT --zjit-trace-fallbacks / --zjit-trace-exits Fuchsia traces
# (/tmp/perfetto-PID.fxt) by reason and call site.
#   ruby SCRIPT [--depth N] APP=FILE.fxt ... > summary.tsv
# Prints reason, category, top frame, samples and apps (TSV); the top frame
# is the method that made the fallback send or side exit.
# --categories compile,invalidation counts --zjit-trace-compiles and
# --zjit-trace-invalidation begin events instead; a lazy compile's name is its
# ISEQ location, so a location compiled more than once was recompiled.
depth = ARGV.include?("--depth") ? Integer(ARGV[ARGV.index("--depth") + 1]) : 1
categories = ARGV.include?("--categories") ? ARGV[ARGV.index("--categories") + 1].split(",") : %w[fallback side_exit]
inputs = ARGV.grep(/=/).map { _1.split("=", 2) }

def each_event(path)
  strings = {}
  data = File.binread(path)
  words = data.unpack("Q<*")
  i = 0
  while i < words.size
    header = words[i]
    type = header & 0xF
    size = (header >> 4) & 0xFFF
    break if size == 0
    case type
    when 2 # string record
      index = (header >> 16) & 0x7FFF
      length = (header >> 32) & 0x7FFF
      strings[index] = data.byteslice((i + 1) * 8, length).force_encoding(Encoding::UTF_8)
    when 4 # event record
      n_args = (header >> 20) & 0xF
      event_type = (header >> 16) & 0xF # 2 = duration begin, 3 = duration end
      category = strings[(header >> 32) & 0xFFFF]
      name = strings[(header >> 48) & 0xFFFF]
      frames = []
      j = i + 2
      n_args.times do
        arg = words[j]
        frames << strings[(arg >> 32) & 0xFFFF] if (arg & 0xF) == 6
        j += (arg >> 4) & 0xFFF
      end
      yield category, name, frames unless event_type == 3
    end
    i += size
  end
end

counts = Hash.new { |h, k| h[k] = Hash.new(0) }
inputs.each do |app, path|
  each_event(path) do |category, reason, frames|
    next unless categories.include?(category)
    site = frames.empty? ? "" : frames.first(depth).join(" < ")
    counts[[category, reason, site]][app.sub(/-mysql\z/, "")] += 1
  end
end
puts %w[category reason site samples apps app_names].join("\t")
counts.sort_by { |_, per_app| -per_app.values.sum }.each do |(category, reason, site), per_app|
  puts [category, reason, site, per_app.values.sum, per_app.size, per_app.keys.sort.join(",")].join("\t")
end
