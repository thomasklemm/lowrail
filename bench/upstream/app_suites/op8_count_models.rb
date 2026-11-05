# bench/upstream/app_suites/op8_count_models.rb. Counts the models whose default attributes main freezes (#59083) and how many of them each OP8 form sends back to
# the writable defaults. Run inside a booted app: bin/rails runner path/to/op8_count_models.rb
# Works on Rails 8.0+ as well as main: "frozen on main" is computed as "no UserProvidedDefault" (main's only
# non-freezable attribute), so apps pinned to a released Rails can be counted without booting them on main.
Rails.application.eager_load!
mutable = ActiveModel::Type::Helpers::Mutable
unwrap = ->(t) { t = t.__getobj__ while t.is_a?(::Delegator) && !t.is_a?(mutable); t }
# The nil-default form (Type#freezable_default?), emulated so it also runs on released Rails.
nil_form = lambda do |t, raw|
  next t.freezable_default?(raw) if t.respond_to?(:freezable_default?)
  case t
  when ActiveRecord::Type::Serialized then false
  when ::Delegator then nil_form.(t.__getobj__, raw)
  when ActiveRecord::Encryption::EncryptedAttributeType then nil_form.(t.cast_type, raw)
  when mutable then raw.nil?
  else true
  end
end
models = ActiveRecord::Base.descendants.reject(&:abstract_class?).select do |m|
  m.name && m.table_exists?
rescue StandardError
  false
end.sort_by(&:name)
rows = models.filter_map do |m|
  attrs = m._default_attributes
  attrs = attrs.keys.map { attrs[_1] }
  next [m.name, :proc_default, []] if attrs.any?(ActiveModel::Attribute::UserProvidedDefault)
  muts = attrs.select { unwrap.(_1.type).is_a?(mutable) }
  narrow = muts.reject { nil_form.(_1.type, _1.value_before_type_cast) }
  [m.name, muts.empty? ? :frozen : (narrow.empty? ? :nil_only : :fallback), muts.map { |a| "#{a.name}:#{unwrap.(a.type).class.name.split("::").last}#{a.value_before_type_cast.nil? ? "" : "=#{a.value_before_type_cast.inspect[0, 20]}"}" }]
rescue StandardError => e
  [m.name, :error, [e.class.name]]
end
by = rows.group_by { _1[1] }.transform_values(&:size)
total = rows.size
frozen_main = total - by.fetch(:proc_default, 0) - by.fetch(:error, 0)
type_level = by.fetch(:nil_only, 0) + by.fetch(:fallback, 0)
puts "models=#{total} frozen_on_main=#{frozen_main} proc_default=#{by.fetch(:proc_default, 0)} errors=#{by.fetch(:error, 0)}"
puts "type-level form falls back: #{type_level} of #{total} (#{type_level} of #{frozen_main} frozen on main)"
puts "nil-default form falls back: #{by.fetch(:fallback, 0)} of #{total} (#{by.fetch(:fallback, 0)} of #{frozen_main} frozen on main)"
if defined?(ActiveModel::ReadOnlyAttributeSet)
  actual = models.count { _1._default_attributes.is_a?(ActiveModel::ReadOnlyAttributeSet) }
  puts "ReadOnlyAttributeSet on this tree: #{actual}"
end
rows.each { |n, s, d| puts "  #{s} #{n} #{d.join(" ")}" unless s == :frozen } if ENV["VERBOSE"]
