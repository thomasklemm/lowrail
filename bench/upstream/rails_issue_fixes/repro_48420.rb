require "active_record"
require "minitest/autorun"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "group_by_test")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table :bookings, force: true }
class Booking < ActiveRecord::Base; end
class BugTest < Minitest::Test
  def setup; Booking.create!; end
  def teardown; Booking.delete_all; end
  def test_group_by
    assert_equal Range, Booking.group("tsrange(timestamp '2020-01-01', timestamp '2020-01-02', '[)') ").count(:id).keys.first.class
  end
  def test_group_by_join
    gc = Booking.joins("JOIN (SELECT tsrange(timestamp '2020-01-01', timestamp '2020-01-02', '[)') AS range) ranges ON TRUE").group('ranges.range').count(:id)
    assert_equal Range, gc.keys.first.class
  end
end
