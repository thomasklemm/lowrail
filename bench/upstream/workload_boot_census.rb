# frozen_string_literal: true

# Separate one-boot allocation attribution. Never mix cold boot and warm ops.
require_relative "workload_census"

name, output = ARGV
raise "fresh output required" if File.exist?(output)
class_of = Kernel.instance_method(:class)
GC.start
ObjectSpace.trace_object_allocations_clear
raise "GC already disabled" if GC.disable
generation = GC.count
before = GC.stat(:total_allocated_objects)
ObjectSpace.trace_object_allocations_start
boot_objects = WorkloadCensus.boot(name)
ObjectSpace.trace_object_allocations_stop
allocated = GC.stat(:total_allocated_objects) - before
raise "boot collected despite disabled GC" unless GC.count == generation
rows = Hash.new(0)
files = {}
ObjectSpace.each_object do |object|
  next unless ObjectSpace.allocation_generation(object) == generation
  file = ObjectSpace.allocation_sourcefile(object)
  owner, path = files[file] ||= WorkloadCensus.source(file)
  rows[[owner, path, ObjectSpace.allocation_sourceline(object), class_of.bind_call(object).name || "<anonymous>"]] += 1
end
GC.enable
ObjectSpace.trace_object_allocations_clear
result = { app: name, ruby: RUBY_DESCRIPTION, yjit: RubyVM::YJIT.enabled?, rails: Rails.version,
  scope: "one production boot/eager-load; warm Bootsnap caches; GC disabled for attribution; untimed",
  source: File.read(".lowrail-corpus-source").strip, lock_sha256: Digest::SHA256.file("Gemfile.lock").hexdigest,
  boot_objects: boot_objects, traced_objects: allocated, enumerated: rows.values.sum, unenumerated: allocated - rows.values.sum,
  sites: rows.sort_by { |key, n| [-n, key.to_s] }.map { |(owner, file, line, klass), n|
    { owner: owner, file: file, line: line, class: klass, objects_per_boot: n } } }
File.write(output, JSON.pretty_generate(result) + "\n")
puts JSON.generate(result.except(:sites))
