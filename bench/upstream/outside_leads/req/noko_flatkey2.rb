# Measurement patch: flat cache key read from the visitor's ivars (no config Hash per lookup).
Nokogiri::CSS::SelectorCache.singleton_class.prepend(Module.new do
  def key(selector:, visitor:)
    [selector, visitor.instance_variable_get(:@builtins), visitor.instance_variable_get(:@doctype),
      visitor.instance_variable_get(:@prefix), visitor.instance_variable_get(:@namespaces)]
  end
end)
