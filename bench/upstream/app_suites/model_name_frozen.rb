# OpenProject's TabularFormBuilder#date_picker does `@object_name.to_s.sub!(/\[\]$/, "")`, and form_for's
# object_name is the model's `model_name.param_key`. RAILS=/path/to/rails ruby model_name_frozen.rb
rails = ENV.fetch("RAILS")
%w[activesupport activemodel].each { |g| $LOAD_PATH.unshift File.join(rails, g, "lib") }
require "active_model"
class CostEntry
  extend ActiveModel::Naming
end
begin
  CostEntry.model_name.param_key.to_s.sub!(/\[\]$/, "")
  puts "param_key mutable: #{CostEntry.model_name.param_key}"
rescue FrozenError => e
  puts "FrozenError: #{e.message}"
end
