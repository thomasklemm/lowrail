require "bundler/setup"; $LOAD_PATH.unshift ARGV[0]; require "graphql"
docs = { "introspection" => 2000, "big_query" => 300, "mutation" => 3000 }.map { |k, n| [k, File.read("/tmp/gqq/#{k}.gql"), n] }
docs.each { |_, s, n| (n / 4).times { GraphQL.parse(s) } }
out = docs.map { |k, s, n| GC.start; t = Process.clock_gettime(Process::CLOCK_MONOTONIC); n.times { GraphQL.parse(s) }; "#{k}=#{((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / n * 1e6).round(2)}" }
puts out.join(" ")
