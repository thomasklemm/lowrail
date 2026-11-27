require 'hashie'
k = Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::DefineAccessors }
m = k.new; m.default_proc = proc { |h, key| h[key.upcase!] = 7 }
p((m.missing rescue $!.class), m.to_hash)
