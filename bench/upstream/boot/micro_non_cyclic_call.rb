class Base
  def self._reflect_on_association(n) = :refl
  def save_collection_association(r) = true
  def _non_cyclic(name, rname, method)
    result = true; @_already_called ||= {}
    unless @_already_called[name]
      reflection = self.class._reflect_on_association(rname)
      if reflection
        begin
          @_already_called[name] = true
          result = public_send(method, reflection)
        ensure
          @_already_called[name] = false
        end
      end
    end
    result
  end
  class_eval <<~RUBY
    def cur(*args)
      result = true; @_already_called ||= {}
      unless @_already_called[:cur]
        reflection = self.class._reflect_on_association(:comments)
        if reflection
          begin
            @_already_called[:cur] = true
            result = save_collection_association(reflection)
          ensure
            @_already_called[:cur] = false
          end
        end
      end
      result
    end
    def slim(*) = _non_cyclic(:slim, :comments, :save_collection_association)
  RUBY
end
o = Base.new
n = 2_000_000
3.times do
  %i[cur slim].each do |m|
    t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    i = 0; while i < n; o.public_send(m); i += 1; end
    print "#{m} #{((Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t) * 1e9 / n).round} ns  "
  end
  puts
end
