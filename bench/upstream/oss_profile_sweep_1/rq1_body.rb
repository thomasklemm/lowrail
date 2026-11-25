# RQ1: one TOTP provisioning QR code, as Redmine's two-factor setup page renders it
# (app/views/twofa/totp/_new.html.erb), at the default ARCH_BITS of a 64-bit Ruby.
require "rqrcode_core"

uri = "otpauth://totp/Redmine:jsmith%40somenet.foo?secret=ABCDEFGHIJKLMNOPQRSTUVWXYZ234567&issuer=Redmine"
UpstreamBench.report("QRCode.new(totp_uri)") { RQRCodeCore::QRCode.new(uri) }
