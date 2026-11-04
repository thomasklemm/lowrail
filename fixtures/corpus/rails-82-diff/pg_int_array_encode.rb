require "active_record"; require "active_record/connection_adapters/postgresql_adapter"
t = ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::Integer.new)
vals = [[], [1, nil, 3], [[1, 2], [3, 4]], ["1", "x", "", " 2 "], [2**40, -2**63, 2**70], [1.9, -1.5], [true, false], [[]], [[nil]], [nil], "{1,2}", 7, nil, [BigDecimal("1.5")], ["1e3"], [[1], 2]]
vals.each { |v| s = (t.serialize(v) rescue next puts("#{v.inspect} => !#{$!.class}")); r = s.respond_to?(:encoder) ? s.encoder.encode(s.values) : s; puts "#{v.inspect} => #{(r rescue $!).inspect} | #{t.cast(v).inspect rescue $!} | #{t.deserialize(r).inspect rescue $!}" }
