# frozen_string_literal: true

require "active_record"

script = File.expand_path("../../l3_ips.rb", __dir__)
eval(File.read(script).split("Benchmark.ips do").first, TOPLEVEL_BINDING, script)
post = TOPLEVEL_BINDING.local_variable_get(:post)
puts "columns=#{Post.column_names.length}"
puts "for_database_owner=#{post.instance_variable_get(:@attributes).method(:values_for_database).owner}"

[:attributes_for_database, :attributes_before_type_cast].each do |method|
  100.times { post.public_send(method) }
  counts = 5.times.map do
    GC.start
    GC.disable
    before = GC.stat(:total_allocated_objects)
    1000.times { post.public_send(method) }
    count = GC.stat(:total_allocated_objects) - before
    GC.enable
    count / 1000.0
  end
  puts "#{method} allocated_per_call=#{counts.min} all=#{counts.inspect}"
end

[:attributes_for_database, :attributes_before_type_cast].each do |method|
  counts = 5.times.map do
    fresh = Post.find(post.id)
    GC.start
    GC.disable
    before = GC.stat(:total_allocated_objects)
    fresh.public_send(method)
    count = GC.stat(:total_allocated_objects) - before
    GC.enable
    count
  end
  puts "#{method} cold_allocated_per_call=#{counts.min} all=#{counts.inspect}"
end

ActiveRecord::Schema.define do
  create_table(:encrypted_records) { |t| t.string :secret; t.string :nil_column }
end
ActiveRecord::Encryption.configure(primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32)

class EncryptedRecord < ActiveRecord::Base
  encrypts :secret
end

created = EncryptedRecord.create!(secret: "secret")
record = EncryptedRecord.find(created.id)
first = record.attributes_for_database
second = record.attributes_for_database
puts "ciphertext_stable=#{first.fetch("secret") == second.fetch("secret")}"
puts "Marshal_stable=#{Marshal.dump(record) == Marshal.dump(record)}"
puts "same_ciphertext_object=#{first.fetch("secret").equal?(second.fetch("secret"))}"
record.attributes
puts "accessed_after_attributes=#{record.accessed_fields.inspect}"
