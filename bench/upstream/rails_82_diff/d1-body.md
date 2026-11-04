### Avoid MemCacheStore bulk-write timeouts with older Dalli

`MemCacheStore#write_multi` sends the entries with Dalli's `set_multi` whenever Dalli defines it. Dalli added `set_multi` in 4.1.0, but before 4.3.6 its binary protocol waited for a reply to every quiet set, and memcached sends no reply for successful quiet sets. The values are stored, but the call waits out the socket timeout once for each key.

The binary protocol is Dalli 4's default, so an application that upgrades Rails and keeps Dalli 4.1 to 4.3.5 finds `write_multi`, `fetch_multi` with misses and cached collection rendering blocking on every key they write. Rails 8.1 writes the keys one by one and is not affected.

Dalli fixed this in 4.3.6 ([petergoldstein/dalli@a2599dc](https://github.com/petergoldstein/dalli/commit/a2599dc6027bd1743e1933fedb90b501a8654e70)). Check for that version, as the store already does for `delete_multi`, so older Dalli versions use individual writes and newer ones keep pipelined writes. The gate checks only the version, so older clients on the meta protocol also get individual writes, which keeps the check simple. The `set_multi` test skips under the same condition; Rails' bundle (Dalli 5.0.6) still exercises the bulk path, so the test doesn't reproduce the old failure.

---

<sub>Found by running the same generated data through Rails 8-1-stable and main side by side ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-82-differential.md), part of my research project Lowrail).</sub>
