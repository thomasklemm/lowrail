# frozen_string_literal: true
# Logs every backend lookup and MissingTranslation for one f.label / f.submit call.
src = File.read(File.expand_path("form_stack_trace.rb", __dir__))
eval(src[0...src.index("require_relative")], TOPLEVEL_BINDING, "form_stack_trace.rb")
LOG = []
I18n::Backend::Simple.prepend(Module.new do
  def lookup(locale, key, scope = [], options = {})
    r = super
    LOG << "lookup #{[scope, key].flatten.compact.join('.')} -> #{r.nil? ? 'miss' : r.inspect[0, 30]}"
    r
  end
end)
I18n::MissingTranslation.prepend(Module.new do
  def initialize(*) = (super; LOG << "  MissingTranslation #{key}")
end)
require_relative "form_stack_patches"
%w[f.label f.submit].each do |l|
  fn = SCENARIOS.fetch(l); 2.times { fn.call }
  LOG.clear; out = fn.call
  puts "== #{l} => #{out}"; puts LOG.map { "  #{_1}" }
end
