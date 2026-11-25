# rq_diff.rb: the new rszf against the old formula, for both ARCH_BITS, across signs and sizes.
$LOAD_PATH.unshift File.join(ARGV[0], "lib")
require "rqrcode_core"
bits = RQRCodeCore::QRUtil::ARCH_BITS
old = ->(num, count) { (num >> count) & ((1 << (bits - count)) - 1) }
values = [0, 1, 2, 255, 0x80, 2**31 - 1, 2**31, 2**32 - 1, 2**32, 2**61, 2**62 - 1, 2**62, 2**63, 2**64 - 1, 2**64, 2**65 + 7, -1, -2, -255, -(2**32), -(2**62), -(2**64), -(2**70)]
values += Array.new(2000) { rand(-2**70..2**70) } + Array.new(2000) { rand(0..2**20) }
checked = 0
values.each { |v| (0..bits).each { |c| raise "#{v} #{c}" unless RQRCodeCore::QRUtil.rszf(v, c) == old.(v, c); checked += 1 } }
srand(1)
strings = Array.new(300) { Array.new(rand(1..200)) { rand(32..126).chr }.join } + ["", "0", "40952", "2 1058 657682"]
require "digest"; digest = Digest::SHA256.hexdigest(strings.map { RQRCodeCore::QRCode.new(_1).to_s }.join)[0, 16]
puts "ARCH_BITS=#{bits}: #{checked} rszf cases equal; QR text of #{strings.size} strings: #{digest}"
