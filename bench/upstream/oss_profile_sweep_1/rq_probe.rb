# rq_probe.rb DIR: objects per RQRCodeCore::QRCode.new for a TOTP provisioning URI, from the tree given.
$LOAD_PATH.unshift File.join(ARGV[0], "lib")
require "rqrcode_core"
uri = "otpauth://totp/Redmine:jsmith%40somenet.foo?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567&issuer=Redmine"
3.times { RQRCodeCore::QRCode.new(uri) }
GC.start; GC.disable
counts = ObjectSpace.count_objects.dup
before = GC.stat(:total_allocated_objects)
n = 20
n.times { RQRCodeCore::QRCode.new(uri) }
total = (GC.stat(:total_allocated_objects) - before).fdiv(n)
big = 0
ObjectSpace.each_object(Integer) { big += 1 }
puts "#{RUBY_VERSION} ARCH_BITS=#{RQRCodeCore::QRUtil::ARCH_BITS}: #{total.round(1)} objects per QRCode.new; live Bignums now #{big}"
q = RQRCodeCore::QRCode.new(uri)
require "digest"; puts "modules sha #{Digest::SHA256.hexdigest(q.modules.flatten.map { _1 ? 1 : 0 }.join)[0, 16]}"
