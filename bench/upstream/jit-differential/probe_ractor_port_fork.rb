port = Ractor::Port.new
Thread.new { port.receive }
sleep 0.1
pid = fork do
  3.times { GC.start }
  junk = Array.new(20000) { "y" * 1000 }  # reuse freed malloc memory
  port.close
  puts "child ok"
end
Process.wait(pid)
p $?
