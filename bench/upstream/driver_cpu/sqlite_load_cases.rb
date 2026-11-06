# frozen_string_literal: true

load File.join(__dir__, "cases.rb")

{
  "select20_load" => DriverRow.select(:id, :name).where(id: 1..20),
  "select1000_load" => DriverRow.select(:id, :name).where(id: 1..1000),
  "wide20_load" => DriverRow.where(id: 1..20),
  "wide1000_load" => DriverRow.where(id: 1..1000)
}.each do |name, relation|
  expected = name.include?("1000") ? (1..1000).to_a : (1..20).to_a
  work = -> { relation.spawn.to_a }
  raise "wrong loaded records: #{name}" unless work.call.map(&:id) == expected
  MICRO[name] = -> { work }
end
