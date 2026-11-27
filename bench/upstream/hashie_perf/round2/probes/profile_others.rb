# frozen_string_literal: true

# Objects by allocation site for Dash, Trash, Coercion and IndifferentAccess, on hashie's own benchmark shapes.
# Usage: ruby -I HASHIE/lib -I HASHIE/benchmarks profile_others.rb HASHIE
require 'objspace'
def duel(*) = nil
root = ARGV.fetch(0)
require "#{root}/benchmarks/benchmark_helper"
load "#{root}/benchmarks/dash_benchmark.rb"
load "#{root}/benchmarks/extensions_benchmark.rb"

dash_attributes = repository_attributes(:id, :name, :full_name, :description)
dash = RepositoryDash.new(repository_attributes(:id, :name, :full_name, :description, :stargazers_count))
trash_attributes = repository_attributes(:id, :full_name, :stargazers_count, :topics)
coerced = { id: '1296269', name: :'Hello-World', stargazers_count: '80', topics: %i[octocat api] }.freeze
nested = JSON.parse(REPOSITORY_JSON, symbolize_names: true).slice(:id, :owner, :licenses).freeze
indifferent = IndifferentHash.new(repository)
sources = Array.new(40) { repository }

WORK = {
  'Dash.new' => -> { RepositoryDash.new(dash_attributes) },
  'Dash read x4, write x2' => -> { dash.name; dash.full_name; dash[:stargazers_count]; dash[:topics]; dash.description = 'x'; dash[:archived] = true },
  'Trash.new' => -> { RepositoryTrash.new(trash_attributes) },
  'Dash.new coerced' => -> { CoercedRepositoryDash.new(coerced) },
  'Dash.new nested coercion' => -> { NestedRepositoryDash.new(nested) },
  'IndifferentAccess.new' => -> { IndifferentHash.new(sources.pop) },
  'IndifferentAccess read x5' => -> { indifferent['name']; indifferent[:full_name]; indifferent[:owner]['login']; indifferent.fetch(:homepage); indifferent.key?(:archived) }
}.freeze

WORK.each do |name, work|
  3.times { work.call }
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  work.call
  total = GC.stat(:total_allocated_objects) - before
  sites = Hash.new(0)
  ObjectSpace.trace_object_allocations do
    gen = GC.count
    work.call
    ObjectSpace.each_object do |o|
      file = ObjectSpace.allocation_sourcefile(o) or next
      next unless ObjectSpace.allocation_generation(o) == gen && file.include?('/lib/hashie')

      sites[[file.sub(%r{.*/lib/}, ''), ObjectSpace.allocation_sourceline(o), o.class.name || o.class.superclass.name]] += 1
    end
  end
  GC.enable
  puts "== #{name}: #{total} objects"
  sites.sort_by { |_, n| -n }.first(8).each { |(f, l, c), n| puts format('%6d  %s:%d %s', n, f, l, c) }
end
