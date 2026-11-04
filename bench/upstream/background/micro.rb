# frozen_string_literal: true

# Background census per-call micro (docs/upstream/background-census.md), for a Rails checkout given in RAILS:
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ir     N calls inside Array#cycle (GC off), for
#                                                         Callgrind --toggle-collect=rb_ary_cycle (ir.sh)
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N stats  objects per call
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ns     wall ns per call over N calls, GC on (ns.sh)
# Loads Rails from the checkout's lib directories and Active Storage's models with Zeitwerk, so a
# Ruby without a bundle (master) runs it too.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord activejob activestorage].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "active_storage"
require "active_storage/reflection"
require "marcel"
require "zeitwerk"

# What the engine's isolate_namespace and boot-time service check would do in an app.
ActiveStorage.define_singleton_method(:table_name_prefix) { "active_storage_" }
loader = Zeitwerk::Loader.new
loader.push_dir(File.join(rails, "activestorage/app/models"))
loader.setup
ActiveStorage::Attached::Model.define_singleton_method(:validate_global_service_configuration) { |*| }
ActiveRecord::Base.include(ActiveStorage::Attached::Model)
ActiveRecord::Base.include(ActiveStorage::Reflection::ActiveRecordExtensions)
ActiveRecord::Reflection.singleton_class.prepend(ActiveStorage::Reflection::ReflectionExtension)
ActiveStorage.verifier = ActiveSupport::MessageVerifier.new("background-census")
ActiveStorage.variant_processor = :disabled
ActiveStorage.variable_content_types = %w[image/png image/gif image/jpeg image/tiff image/bmp image/vnd.adobe.photoshop image/vnd.microsoft.icon image/webp image/avif image/heic image/heif]
ActiveStorage.web_image_content_types = %w[image/png image/jpeg image/gif]

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:active_storage_blobs) do |t|
    t.string :key, :filename, :content_type, :service_name, :checksum
    t.text :metadata
    t.bigint :byte_size
    t.datetime :created_at
  end
end

blob = ->(filename, content_type) do
  ActiveStorage::Blob.new(key: "k", filename: filename, content_type: content_type, byte_size: 1, checksum: "c",
    service_name: "local", metadata: { identified: true })
end
PNG = blob.("avatar.png", "image/png")
JPEG = blob.("IMG_20240101_123456 photo.jpeg", "image/jpeg")
MISMATCH = blob.("scan.png", "image/jpeg")

[ActiveStorage::Blob.instance_method(:variant), ActiveStorage::Filename.instance_method(:sanitized)].each do |m|
  raise "#{m.name} not loaded from #{rails}" unless m.source_location.first.start_with?(File.expand_path(rails) + "/")
end

CASES = {
  "format_png" => -> { PNG.send(:format) },
  "format_jpeg" => -> { JPEG.send(:format) },
  "format_mismatch" => -> { MISMATCH.send(:format) },
  "variant_png" => -> { PNG.variant(resize_to_limit: [100, 100]) },
  "variant_jpeg" => -> { JPEG.variant(resize_to_limit: [100, 100]) },
}

name, n, mode = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
fn = CASES.fetch(name)
500.times { fn.() }
GC.start
GC.disable
case mode
when "ir"
  [nil].cycle(n) { fn.() }
when "stats"
  before = GC.stat(:total_allocated_objects)
  n.times { fn.() }
  puts (GC.stat(:total_allocated_objects) - before).fdiv(n).round(2)
else
  GC.enable
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  n.times { fn.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(n).round(1)
end
