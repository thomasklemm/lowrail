# frozen_string_literal: true

# Census 5 YJIT-only allocation shapes, no Rails. ruby [--yjit] SCRIPT
# Prints objects allocated per call after warmup.
class Model; end

def int_interp(i, j) = "t#{i}_r#{j}"
def class_interp(klass) = "#{klass} Update"
def string_interp(s) = "#{s} Update"

def m(label)
  2_000.times { yield }
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  100.times { yield }
  puts format("%-40s %.2f", label, (GC.stat(:total_allocated_objects) - before) / 100.0)
ensure
  GC.enable
end

name = +"Model"
m('"t#{i}_r#{j}" (Integers)') { int_interp(3, 4) }
m('"#{klass} Update" (a Class)') { class_interp(Model) }
m('"#{s} Update" (a String)') { string_interp(name) }
