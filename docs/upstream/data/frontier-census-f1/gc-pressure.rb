# GC pressure from a background thread: full GC (CASA_GC=start) or compaction (compact) every CASA_GC_S seconds.
mode = ENV.fetch("CASA_GC", "start")
Thread.new { loop { sleep Float(ENV.fetch("CASA_GC_S", "0.02")); mode == "compact" ? (GC.compact rescue nil) : GC.start } }
