N = 4000
FILE = "autosave_association.rb"
def cur(klass, name, rname, method)
  klass.class_eval <<~RUBY, FILE, 185
    def #{name}(*args)
      result = true; @_already_called ||= {}
      # Loop prevention for validation of associations
      unless @_already_called[:#{name}]
        reflection = self.class._reflect_on_association(:#{rname})
        if reflection
          begin
            @_already_called[:#{name}] = true
            result = #{method}(reflection)
          ensure
            @_already_called[:#{name}] = false
          end
        end
      end

      result
    end
  RUBY
end
def slim(klass, name, rname, method)
  klass.class_eval <<~RUBY, FILE, 185
    def #{name}(*) = _non_cyclic(:#{name}, :#{rname}, :#{method})
  RUBY
end
# Boot cost of defining one autosave method: the 17-line body (cur) vs a one-line forwarder (slim).
[:cur, :slim, :cur, :slim].each do |kind|
  k = Class.new
  t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  N.times { |i| send(kind, k, :"autosave_associated_records_for_assoc#{i}", :"assoc#{i}", :save_collection_association) }
  puts "#{kind}: #{((Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t) * 1e6 / N).round(2)} us per association"
end
