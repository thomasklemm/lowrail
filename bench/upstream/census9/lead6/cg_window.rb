# frozen_string_literal: true

# Lead 6: a callgrind_annotate profile of N (default 200) calls of one attr_micro.rb case after WARM (300)
# calls, GC disabled in the window. Run under Callgrind with --instr-atstart=no; the window's dump is the
# out file whose "desc: Trigger" names the case.
#   RAILS=DIR WIDTH=300 valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=OUT.%p ruby cg_window.rb [CASE]
kase = ARGV.first || "update1"
n = Integer(ENV.fetch("N", "200"))
warm = Integer(ENV.fetch("WARM", "300"))
ENV["N"] = "1"
ENV["WARM"] = "1"
ARGV.replace([kase])
$stdout = File.open(File::NULL, "w")
load File.expand_path("../attr_micro.rb", __dir__)
$stdout = STDOUT
require ENV.fetch("CG_CTL_SO", File.expand_path("~/c9/ext/cg_ctl.so"))
fn = CASES.fetch(kase)
warm.times { fn.() }
GC.start
GC.disable
CgCtl.zero
n.times { fn.() }
CgCtl.dump(kase)
GC.enable
