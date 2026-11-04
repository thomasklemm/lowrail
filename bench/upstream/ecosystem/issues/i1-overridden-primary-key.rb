# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "rails", github: "rails/rails", branch: ENV.fetch("RAILS_BRANCH", "main")
  gem "sqlite3"
end

require "active_record"
require "minitest/autorun"
require "logger"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = Logger.new(STDOUT)

ActiveRecord::Schema.define do
  create_table :menu_items, id: false, force: true do |t|
    t.string :uuid_key
    t.string :name
  end
end

class MenuItem < ActiveRecord::Base
  def self.primary_key
    "uuid_key"
  end
end

class BugTest < ActiveSupport::TestCase
  def setup
    MenuItem.find_or_create_by!(uuid_key: "abc", name: "Soup")
  end

  def test_class_find_uses_overridden_primary_key
    assert_equal "Soup", MenuItem.find("abc").name
  end

  def test_relation_find_uses_overridden_primary_key
    assert_equal "Soup", MenuItem.all.find("abc").name
  end

  def test_relation_find_many_uses_overridden_primary_key
    assert_equal ["Soup"], MenuItem.all.find(["abc"]).map(&:name)
  end
end
