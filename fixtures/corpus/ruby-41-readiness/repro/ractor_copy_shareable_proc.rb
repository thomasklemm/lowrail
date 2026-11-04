# Ruby master: Ractor.make_shareable(copy: true) fails on a graph that holds a
# shareable Proc next to a Set (or Time). 4.0.9 copies it. Bug #22267 (open).
# Active Support hits it in Notifications.record_subscriptions with a Regexp
# subscriber (Fanout::Matcher keeps a Set of exclusions).
pr = Ractor.shareable_proc { }
[[:set, -> { [pr, Set.new] }], [:time, -> { [pr, Time.now] }], [:hash, -> { [pr, {a: 1}] }]].each do |name, mk|
  Ractor.make_shareable(mk.call, copy: true)
  puts "#{name}: ok"
rescue => e
  puts "#{name}: #{e.class}: #{e.message} (cause: #{e.cause&.message})"
end
