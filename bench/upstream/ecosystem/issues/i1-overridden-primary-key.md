### Relation `find` ignores an overridden `self.primary_key` on main

Overriding the class method documented as "can be overridden in subclasses" no longer reaches relation finders on main. `Model.find(id)` still works, but `Model.all.find(id)` and `Model.all.find([ids])` build the condition from `primary_key_definition`. That reads the schema, which has no primary key here, so the column name comes out empty:

```
main:       SELECT "menu_items".* FROM "menu_items" WHERE "menu_items"."" = ? LIMIT ?
8-1-stable: SELECT "menu_items".* FROM "menu_items" WHERE "menu_items"."uuid_key" = ? LIMIT ?
```

On main the script below fails with `ActiveRecord::StatementInvalid: no such column: menu_items.`; on 8-1-stable (`RAILS_BRANCH=8-1-stable`) it passes. Bisecting points to 55406a9794 ("Introduce ActiveRecord::PrimaryKey value object for composite keys"), whose message says "The public `primary_key` API (String/Array/nil) is unchanged." friendly_id's test suite hits this (`UuidAsPrimaryKeyFindTest`).

```ruby
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
  def test_relation_find_uses_overridden_primary_key
    MenuItem.create!(uuid_key: "abc", name: "Soup")

    assert_equal "Soup", MenuItem.find("abc").name
    assert_equal "Soup", MenuItem.all.find("abc").name
    assert_equal ["Soup"], MenuItem.all.find(["abc"]).map(&:name)
  end
end
```
