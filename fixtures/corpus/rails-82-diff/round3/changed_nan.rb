# Same on 8.1 and main: dirty tracking raises after a NaN is assigned to a date or datetime attribute.
require "active_model"
require "bigdecimal"
class Person
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  attribute :born_on, :date
end
person = Person.new(born_on: Date.new(2000, 1, 1))
person.changes_applied
person.born_on = Float::NAN
person.changed? # ArgumentError: comparison of Rational with NaN failed (Date#<=> through Value#changed?)
