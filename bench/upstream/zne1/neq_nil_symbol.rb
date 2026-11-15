require_relative '../lib/harness/loader'

# The attribute-type check of ActionView's tag_options: the type is nil for most attributes
# and a Symbol for data:, aria: and class:.
TYPES = [nil, nil, :data, nil, :class, nil, nil, :aria].freeze
VALUES = ["/users/42", "author-link", { id: 1 }, "Jane Doe", "byline", "get", "post", { label: "x" }].freeze

def nested?(type, value)
  type != :aria && type != :class && value.is_a?(Hash)
end

def count_nested
  count = 0
  i = 0
  while i < 800
    count += 1 if nested?(TYPES[i & 7], VALUES[i & 7])
    i += 1
  end
  count
end

# Warm up outside the measured iterations, so each one runs compiled code from the start.
100.times { count_nested }

run_benchmark(100) do
  count = 0
  i = 0
  while i < 2_500
    count += count_nested
    i += 1
  end
  raise "wrong count: #{count}" unless count == 250_000
end
