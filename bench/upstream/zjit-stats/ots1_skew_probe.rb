def t(a) = "<#{a}>"
ARGS = ENV.fetch("ARGS").split(",").map { _1.start_with?(":") ? _1[1..].to_sym : _1 }
ARGS.each { t(_1) }
s0 = RubyVM::ZJIT.stats
2000.times { t(:sym) }
s1 = RubyVM::ZJIT.stats
puts "exits=#{s1[:side_exit_count] - s0[:side_exit_count]} dyn=#{s1[:dynamic_send_count] - s0[:dynamic_send_count]}"
