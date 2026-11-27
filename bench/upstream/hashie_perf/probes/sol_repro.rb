require 'hashie'
klass = Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::StrictKeyAccess }
name = String.new('MISSING'); calls = 0
name.define_singleton_method(:to_s) { calls += 1; ['lookup', 'expected', 'changed'].fetch(calls - 1, 'changed') }
begin; klass.new.method_missing(name); rescue KeyError => e; p [e.message, calls]; end
