# Loaded with -r during the base suite: records every argument passed to
# Rack::Utils.escape/unescape and QueryParser#unescape that Marshal can dump,
# leaving out strings over 2 KB (the limit tests' megabyte inputs).
$rk3_seen = {}
tp = TracePoint.new(:call) do |t|
  next unless %i[escape unescape].include?(t.method_id)
  owner = t.defined_class.to_s
  next unless owner.include?("Rack::Utils") || owner.include?("Rack::QueryParser")
  b = t.binding
  args = b.local_variables.include?(:string) ? [b.local_variable_get(:string)] : [b.local_variable_get(:s)]
  args << b.local_variable_get(:encoding) if t.method_id == :unescape
  next if args[0].respond_to?(:bytesize) && args[0].bytesize > 2048
  key = [t.method_id, args]
  begin
    $rk3_seen[Marshal.dump(key)] = true
  rescue TypeError
  end
end
tp.enable
at_exit do
  File.open(ENV.fetch("RK3_RECORD"), "ab") { |f| $rk3_seen.each_key { |k| f.write([k.bytesize].pack("N"), k) } }
end
