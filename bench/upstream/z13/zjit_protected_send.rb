require_relative '../lib/harness/loader'

# ActiveSupport::InheritableOptions reads a missing key from its parent through a protected alias of Hash#[].
class Options < Hash
  alias_method :_get, :[]
  protected :_get

  def initialize(parent = nil)
    if parent
      super() { |_, key| parent._get(key) }
    else
      super()
    end
  end
end

BASE = Options.new
BASE[:asset_host] = "x"
LEAF = Options.new(Options.new(BASE))

run_benchmark(10) do
  i = 0
  while i < 500_000
    LEAF[:asset_host]
    i += 1
  end
end
