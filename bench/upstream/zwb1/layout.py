# gdb -batch -x bench/upstream/zwb1/layout.py BINARY (a ZJIT miniruby or ruby): IseqPayload's size, alignment and field offsets from DWARF.
import gdb
t = gdb.lookup_type('zjit::payload::IseqPayload')
print("sizeof", t.sizeof, "alignof", t.alignof)
end = 0
for f in sorted(t.fields(), key=lambda f: f.bitpos):
    print(f"{f.bitpos // 8:4} {f.type.sizeof:4}  {f.name}")
    end = max(end, f.bitpos // 8 + f.type.sizeof)
print("tail padding", t.sizeof - end)
