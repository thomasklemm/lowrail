# frozen_string_literal: true

# Aggregates the heap dumps of one detail run (mem.rb with DUMP_DIR):
#   ruby dump.rb DUMP_DIR APP_DIR MEM_JSONL OUT.json
# Per snapshot (boot, r1000, r5000): live bytes by type, imemo type and owner,
# the top allocation sites, instruction sequences by the file they were
# compiled from (an ISEQ's allocation site is the require that compiled it, so
# it is attributed through the path String it references), and Strings with
# identical contents (duplicates beyond the first copy, by owner and site).
# Growth: objects in the last dump allocated after the first request snapshot
# (generation above that snapshot's GC count), by owner and site.
# Owners: app, rails/COMPONENT, gem/NAME, ruby/stdlib, (untraced) for objects
# allocated before tracing or by C code with no Ruby frame.
require "json"

dump_dir, app_dir, mem_jsonl, output = ARGV
APP = File.realpath(app_dir) + "/"
RUBYLIB = RbConfig::CONFIG.fetch("rubylibdir") + "/"

def owner(file)
  return "(untraced)" if file.nil?
  return "app" if file.start_with?(APP) && !file.include?("/vendor/")
  if (m = file.match(%r{/bundler/gems/rails-\h+/([a-z]+)/}))
    return "rails/#{m[1]}"
  end
  if (m = file.match(%r{/gems/([^/]+?)-\d[^/]*/}))
    return "gem/#{m[1]}"
  end
  return "ruby/stdlib" if file.start_with?(RUBYLIB)
  return "ruby/(eval)" if file.start_with?("(eval") || file == "-e"
  "(other)"
end

def site(file, line)
  return "(untraced)" if file.nil?
  short = file.sub(APP, "APP/").sub(%r{.*/bundler/gems/rails-\h+/}, "RAILS/").sub(%r{.*/gems/}, "GEM/").sub(RUBYLIB, "RUBY/")
  "#{short}:#{line}"
end

snaps = File.foreach(mem_jsonl).filter_map { JSON.parse(_1)["snapshot"] }
first_gc = snaps.find { _1["label"] != "boot" }&.dig("dump", "gc_count")

def add(h, key, bytes)
  e = (h[key] ||= [0, 0])
  e[0] += 1
  e[1] += bytes
end

def top(h, n) = h.sort_by { -_2[1] }.first(n).map { |k, (c, b)| { key: k, count: c, bytes: b } }

result = { snapshots: {} }
snaps.each do |snap|
  path = File.join(dump_dir, snap.dig("dump", "path"))
  by_type = {}
  by_imemo = {}
  by_owner = {}
  by_owner_type = {}
  sites = {}
  growth_owner = {}
  growth_site = {}
  paths = {}
  iseqs = []
  strings = {}
  total = [0, 0]
  File.foreach(path) do |line|
    o = JSON.parse(line)
    next unless o["address"]
    type = o["type"]
    type = "DATA/#{o["struct"]}" if type == "DATA" && o["struct"]
    bytes = o["memsize"].to_i
    file = o["file"]
    total[0] += 1
    total[1] += bytes
    add(by_type, type, bytes)
    add(by_imemo, o["imemo_type"], bytes) if type == "IMEMO"
    if type == "IMEMO" && o["imemo_type"] == "iseq"
      iseqs << [o["references"] || [], bytes]
      next
    end
    # VM tables (fstring and symbol sets, method cache tables) and the
    # allocation tracer itself are charged to whichever line happened to grow
    # or create them, so they get owners of their own. Threads keep their site.
    own = if type.start_with?("DATA/ObjectTracing") then "(tracer)"
    elsif type == "DATA/VM/cc_table" then "ruby/method-cache"
    elsif (type.start_with?("DATA/VM") && type != "DATA/VM/thread") || type == "DATA/symbol_id_entry_list" then "ruby/vm"
    else owner(file)
    end
    add(by_owner, own, bytes)
    add(by_owner_type, "#{own} #{type == "IMEMO" ? "IMEMO/#{o["imemo_type"]}" : type}", bytes)
    add(sites, "#{site(file, o["line"])} #{type}", bytes)
    if type == "STRING"
      value = o["value"]
      paths[o["address"]] = value if value&.start_with?("/") && value.end_with?(".rb", ".erb", ".rake")
      if value
        e = (strings[[value, o["encoding"]]] ||= [0, 0, Hash.new(0), Hash.new(0)])
        e[0] += 1
        e[1] += bytes
        e[2][own] += bytes
        e[3][site(file, o["line"])] += 1
      end
    end
    if first_gc && snap.equal?(snaps.last) && o["generation"].to_i > first_gc
      add(growth_owner, "#{own} #{type == "IMEMO" ? "IMEMO/#{o["imemo_type"]}" : type}", bytes)
      add(growth_site, "#{site(file, o["line"])} #{type}", bytes)
    end
  end
  iseq_owner = {}
  iseq_file = {}
  iseqs.each do |refs, bytes|
    file = refs.lazy.map { paths[_1] }.find(&:itself)
    add(iseq_owner, file ? owner(file) : "(no path)", bytes)
    add(iseq_file, file ? site(file, "").chomp(":") : "(no path)", bytes)
    add(by_owner, file ? owner(file) : "(untraced)", bytes)
    add(by_owner_type, "#{file ? owner(file) : "(untraced)"} IMEMO/iseq", bytes)
  end
  dups = strings.select { |_, (n, _)| n > 1 }
  dup_owner = Hash.new(0)
  dups.each_value { |n, b, owners, _| owners.each { |own, ob| dup_owner[own] += ob - ob.fdiv(n).round } }
  result[:snapshots][snap["label"]] = {
    objects: total[0], bytes: total[1],
    by_type: top(by_type, 100), by_imemo: top(by_imemo, 50), by_owner: top(by_owner, 200), by_owner_type: top(by_owner_type, 300),
    sites: top(sites, 400), iseq_by_owner: top(iseq_owner, 100), iseq_by_file: top(iseq_file, 150),
    strings: { count: strings.sum { _2[0] }, distinct: strings.size, duplicated_groups: dups.size,
      wasted_bytes: dups.sum { |_, (n, b)| b - b.fdiv(n).round }, wasted_by_owner: dup_owner.sort_by { -_2 }.to_h,
      top: dups.sort_by { |_, (n, b)| -(b - b.fdiv(n)) }.first(80).map { |(v, enc), (n, b, owners, s)|
        { value: v[0, 100], encoding: enc, copies: n, bytes: b, wasted: b - b.fdiv(n).round,
          owners: owners.sort_by { -_2 }.first(4).to_h, sites: s.sort_by { -_2 }.first(4).to_h } } },
  }
  next if growth_owner.empty?
  result[:growth] = { from_gc: first_gc, to: snap["label"], by_owner_type: top(growth_owner, 100), sites: top(growth_site, 200) }
end
File.write(output, JSON.pretty_generate(result) + "\n")
