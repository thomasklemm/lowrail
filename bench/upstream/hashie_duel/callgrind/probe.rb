require "fiddle"

# x86-64 client request: rax = args, rdx = default (0), Valgrind's preamble, result in rdx.
CODE = [0x48, 0x89, 0xf8, 0x31, 0xd2, 0x48, 0xc1, 0xc7, 0x03, 0x48, 0xc1, 0xc7, 0x0d, 0x48, 0xc1, 0xc7, 0x3d,
  0x48, 0xc1, 0xc7, 0x33, 0x48, 0x87, 0xdb, 0x48, 0x89, 0xd0, 0xc3].pack("C*")

libc = Fiddle.dlopen(nil)
mmap = Fiddle::Function.new(libc["mmap"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_INT, Fiddle::TYPE_LONG], Fiddle::TYPE_VOIDP)
mprotect = Fiddle::Function.new(libc["mprotect"], [Fiddle::TYPE_VOIDP, Fiddle::TYPE_SIZE_T, Fiddle::TYPE_INT], Fiddle::TYPE_INT)
page = mmap.call(nil, 4096, 3, 0x22, -1, 0)
page[0, CODE.bytesize] = CODE
raise "mprotect" unless mprotect.call(page, 4096, 5).zero?
REQ = Fiddle::Function.new(page.to_i, [Fiddle::TYPE_VOIDP], Fiddle::TYPE_LONG)
ARGS = Fiddle::Pointer.malloc(48)

def request(code, a1 = 0)
  ARGS[0, 16] = [code, a1].pack("QQ")
  REQ.call(ARGS)
end

CT = (0x43 << 24) | (0x54 << 16)
DUMP, ZERO, TOGGLE, START_INSTR = CT, CT + 1, CT + 2, CT + 4
puts "running on valgrind: #{request(0x1001)}"
exit if request(0x1001).zero?
request(START_INSTR) if ENV["INSTR_LATER"]

out = ENV.fetch("OUT")
def counted(out, n)
  @dumps = (@dumps || 0)
  request(TOGGLE)
  n.times { "a" * 10 }
  request(TOGGLE)
  request(DUMP)
  @dumps += 1
  file = "#{out}.#{@dumps}"
  total = File.foreach(file).find { |l| l.start_with?("totals:") }.split[1].to_i
  File.delete(file)
  total
end
[0, 0, 1, 10, 100, 1000, 1000, 1000].each { |n| puts "n=#{n} Ir=#{counted(out, n)}" }
