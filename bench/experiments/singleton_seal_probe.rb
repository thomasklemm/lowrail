# frozen_string_literal: true

# Finite adversarial screen. Each irreversible freeze gets a fresh process.
require "json"
require "open3"
require "rbconfig"

cases = {
  "memo" => ["", "Subject.instance_variable_set(:@nil_memo, nil); Subject.instance_variable_set(:@false_memo, false)"],
  "ordinary_definition" => ["", "Subject.class_eval { def value = 29 }"],
  "remove" => ["", "Subject.remove_method(:value)"],
  "undef" => ["", "Subject.undef_method(:value)"],
  "saved_define_method" => ["saved = Module.instance_method(:define_method)", "saved.bind_call(Subject, :value) { 29 }"],
  "private" => ["", "Subject.send(:private, :value)"],
  "public" => ["Subject.send(:private, :value)", "Subject.send(:public, :value)"],
  "protected" => ["", "Subject.send(:protected, :value)"],
  "module_function" => ["", "Subject.send(:module_function, :value)"],
  "include" => ["Incoming = Module.new { def value = 29 }", "Subject.include(Incoming)"],
  "prepend" => ["Incoming = Module.new { def value = 29 }", "Subject.prepend(Incoming)"],
  "extend" => ["Incoming = Module.new { def value = 29 }", "Subject.extend(Incoming)"],
  "suppressed_incoming_prepend" => ["raw = Module.instance_method(:prepend_features); Incoming = Module.new { def value = 29 }; Incoming.define_singleton_method(:prepend_features) { |base| raw.bind_call(self, base) }", "Subject.prepend(Incoming)"],
  "callback_before_boot" => ["def Subject.method_added(*); end", "Subject.module_eval { def value = 29 }"],
  "callback_after_boot" => ["", "def Subject.method_added(*); end"],
  "instance_singleton" => ["object = Object.new.extend(Subject)", "object.define_singleton_method(:value) { 29 }"],
  "suppressed_instance_singleton" => ["object = Object.new.extend(Subject); def object.singleton_method_added(*); end", "object.define_singleton_method(:value) { 29 }"],
  "new_subclass_suppression" => ["", "child = Class.new(WatchedClass); def child.singleton_method_added(*); end; def child.method_added(*); end; child.class_eval { def value = 29 }"],
  "refinement" => ["", "r = Module.new { refine(Subject) { def value = 29 } }; using r"],
  "preexisting_refinement" => ["r = Module.new { refine(Subject) { def value = 29 } }", "using r"],
  "native_reader" => ["require 'fiddle'; native = Fiddle::Handle::DEFAULT; intern = Fiddle::Function.new(native['rb_intern'], [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG, need_gvl: true); attr = Fiddle::Function.new(native['rb_attr'], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_LONG, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT], Fiddle::TYPE_VOID, need_gvl: true)",
    "attr.call(Fiddle.dlwrap(Subject), intern.call('value'), 1, 0, 0)"]
}

results = cases.map do |name, (setup, operation)|
  source = <<~RUBY
    module Subject; def value = 7; end
    WatchedClass = Class.new { include Subject }
    #{setup}
    seal = SingletonSeal::Session.new(holders: [Subject, WatchedClass]).start!
    applied = seal.active[0]
    failure = nil
    begin
      #{operation}
    rescue Exception => error
      failure = error.class.name
    end
    puts JSON.generate({name: #{name.inspect}, applied: applied, active: seal.active[0], error: failure, report: seal.finish!})
  RUBY
  output, warning, status = Open3.capture3(RbConfig.ruby, "-r#{File.expand_path('singleton_seal', __dir__)}", "-e", source)
  raise "#{name}: #{warning}" unless status.success?
  JSON.parse(output.lines.last).merge("warning" => warning)
end
puts JSON.pretty_generate(results)
