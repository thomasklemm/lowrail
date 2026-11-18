# frozen_string_literal: true

rails = ENV.fetch("RAILS")
%w[railties activesupport activemodel activerecord].each { |component| $LOAD_PATH.unshift(File.join(rails, component, "lib")) }
$LOAD_PATH.unshift(File.join(rails, "activerecord/test"))
require "cases/helper"
if ActiveRecord.respond_to?(:association_scope_keeps_owner_conditions=)
  ActiveRecord.association_scope_keeps_owner_conditions = ENV.fetch("KEEP") == "1"
end
file = File.join(ENV.fetch("HEAD_RAILS"), "activerecord/test/cases/associations/has_many_associations_test.rb")
source = File.read(file)
start = source.index("class HasManyOwnerConditionsSerializationTest <") or abort "Test class not found"
test = source[start..]
if ENV["MUTATION"] == "drop_default_scope"
  expected = "      default_scope { where(KEYS.index_with(1).merge(key0: 2**70)) }\n"
  abort "Default scope not found" unless test.include?(expected)
  test = test.sub(expected, "")
end
eval(test, TOPLEVEL_BINDING, file, source[0...start].count("\n") + 1)
