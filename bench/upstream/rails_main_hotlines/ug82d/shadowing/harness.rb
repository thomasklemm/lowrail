require "active_record"
require_relative "prototype"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :type; t.integer :position; t.boolean :published } }
puts "after AR load + schema: #{ShadowCheck::HITS.size} hits"

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end
module Searchable
  def default_order = order(id: :desc)        # danbooru shape: extended into the abstract class
  def search(params) = where(params)          # not a relation method
end
ApplicationRecord.extend Searchable

module Sortable
  extend ActiveSupport::Concern
  class_methods { def reorder(positions) = positions }   # otwarchive shape via concern
end

class Post < ApplicationRecord
  include Sortable
  def self.default_order(column = :position) = order(column => :desc)   # case 3 shape
  class << self
    def reverse_order = order(position: :desc)  # discourse shape
    def published = where(published: true)      # ordinary, not shadowed
  end
  define_singleton_method(:lock) { |*a| :app_lock }   # discourse OptimizedImage shape
  def self.table_name = "posts"                 # forwarded by Relation: no hit
  scope :recent, -> { order(id: :desc) }        # scope: not a relation name, no hit
end
class SpecialPost < Post; end                    # STI: inherits, no new definition
puts JSON.pretty_generate(ShadowCheck::HITS)
