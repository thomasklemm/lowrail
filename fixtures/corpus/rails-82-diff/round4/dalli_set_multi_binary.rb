# Dalli alone, no Rails: set_multi with the binary and the meta protocol (memcached on localhost:11290).
require "dalli"
c = Dalli::Client.new("localhost:11290", namespace: "dset#{rand(1e9)}")
def t(l) = (a = Process.clock_gettime(Process::CLOCK_MONOTONIC); r = (yield rescue $!); puts format("%-34s %.3fs %s", l, Process.clock_gettime(Process::CLOCK_MONOTONIC) - a, r.inspect[0, 60]))
p Dalli::VERSION
t("set_multi 3, ttl 0, {}") { c.set_multi({ "a" => "1", "b" => "2", "c" => "3" }, 0, {}) }
t("get_multi") { c.get_multi("a", "b", "c") }
t("set_multi 3, ttl 0, raw") { c.set_multi({ "d" => "1", "e" => "2", "f" => "3" }, 0, raw: true) }
t("get_multi raw") { c.get_multi("d", "e", "f") }
c2 = Dalli::Client.new("localhost:11290", protocol: :meta, namespace: "dset#{rand(1e9)}")
t("meta set_multi 3") { c2.set_multi({ "a" => "1", "b" => "2", "c" => "3" }, 0, {}) }
t("meta get_multi") { c2.get_multi("a", "b", "c") }
