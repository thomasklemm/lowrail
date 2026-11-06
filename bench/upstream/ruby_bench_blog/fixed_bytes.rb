# Control preload: every "random" byte is the same, so session ids, CSRF masks and cookie
# IVs repeat. If iterations then allocate identically, random bytes explain the spread.
require "openssl"
Random.singleton_class.prepend(Module.new { def urandom(n) = ("\x5a".b * n) })
OpenSSL::Cipher.prepend(Module.new { def random_iv = (self.iv = "\x5a".b * iv_len) })
