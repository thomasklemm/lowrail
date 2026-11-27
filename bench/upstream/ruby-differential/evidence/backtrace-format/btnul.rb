def t(label)
  r = yield
  p [label, r]
rescue Exception => e
  p [label, :raised, e.class, e.message]
end
t(:raise_backtrace) { begin; eval("raise 'boom'", nil, "a\0b.rb"); rescue => e; e.backtrace&.first; end }
t(:raise_message) { begin; eval("raise 'boom'", nil, "a\0b.rb"); rescue => e; e.message; end }
t(:full_message) { begin; eval("raise 'boom'", nil, "a\0b.rb"); rescue => e; e.full_message(highlight: false); end }
t(:reraise) { begin; begin; eval("raise 'boom'", nil, "a\0b.rb"); rescue => e; raise e, "again"; end; rescue => e2; [e2.class, e2.message]; end }
t(:locations) { eval("caller_locations(0,1)[0].to_s", nil, "a\0b.rb") }
o = Object.new
def o.m = caller(0, 1)[0]
o.singleton_class.alias_method("x\0y", :m)
t(:nul_method_alias) { o.send("x\0y") }
o.define_singleton_method(:"q\0r") { |*| caller(0, 1)[0] }
t(:nul_method_def) { o.send(:"q\0r") }
k = Class.new { define_method(:"z\0w") { raise "in nul method" } }
t(:nul_method_raise_bt) { begin; k.new.send(:"z\0w"); rescue => e; e.backtrace[0]; end }
