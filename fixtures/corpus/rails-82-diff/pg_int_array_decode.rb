require "active_record"; require "active_record/connection_adapters/postgresql_adapter"
t = ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::Integer.new)
b = ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array.new(ActiveModel::Type::BigInteger.new)
R = Random.new(5)
fixed = ["{}", "{1,2}", "{ 1 , 2 }", "{1.5}", "{x}", "{NULL}", "{null}", "{\"1\"}", "{\"NULL\"}", "{{1,2},{3,4}}", "{1,}", "{,1}", "{-0}", "{+1}", "{007}", "{1e3}", "{99999999999}", "{-2147483649}", "{2147483647}", "[1:2]={1,2}", "{\"\"}", "{ }", "{1 2}", "", "{", "}", "x", "{{}}", "{1,{2}}"]
rand = Array.new(3000) { "{" + Array.new(R.rand(4)) { ["1", "-2", " ", "NULL", "\"3\"", "x", "", "1.5", "{4}", "2147483648", "0x1"].sample(random: R) }.join(",") + "}" }
(fixed + rand).each_with_index { |s, i| puts "#{i} #{s.inspect} => #{(t.deserialize(s) rescue "!#{$!.class}: #{$!.message}").inspect} | #{(b.deserialize(s) rescue "!#{$!.class}").inspect} | #{(t.cast(s) rescue "!#{$!.class}").inspect}" }
