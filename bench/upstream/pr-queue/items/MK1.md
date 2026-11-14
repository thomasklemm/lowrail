---
id: MK1
repo: rails/rails
kind: perf
area: Active Support, MessageEncryptor
reviewer: byroot
branch: thomasklemm/message-encryptor-key-len
head: "9b00915043b5e10b8b926f30aac78065a55b9ef6"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "-2,447 Ir and -2 objects per key_len call (5,833 -> 3,386, Ruby 4.0, no JIT); one call per request with an encrypted cookie jar, below request-level A/A noise"
rank: 24
risky: false
state: held
pr:
note: "P-MAP prototype. Held: on a Blog article request the change is inside Callgrind A/A noise (interpreter: base 8,874,970, A/A +0.08%, MK1 +0.11%; YJIT: base 5,164,117, A/A -0.18%, MK1 -0.19%; -2 objects). Open only together with other cookie-jar work."
passes: []
---

# Look up each cipher's key length once in MessageEncryptor.key_len

`MessageEncryptor.key_len` builds an `OpenSSL::Cipher` only to read its key length, and the encrypted cookie jar
calls it whenever a request reads or writes an encrypted cookie, which includes loading a cookie store session.

A cipher's key length never changes, so it is now kept per cipher name in a per-Ractor `Concurrent::Map`. Cipher
names come from configuration, so the map stays as small as the set of configured ciphers, and an unknown cipher
still raises and isn't stored.

Instructions and objects per call, Ruby 4.0, no JIT:

| | before | after |
|---|---:|---:|
| `MessageEncryptor.key_len("aes-256-gcm")` | 5,833 (3 objects) | 3,386 (1 object) |
