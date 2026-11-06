# P-PUMA: CPU outside the Rack application

2026-11-06. Ruby **4.0.9**, interpreter and YJIT, real loopback TCP. This is a
diagnostic investigation, not a certified speedup or a throughput claim.

**Decision: no PR-ready new Puma candidate.** The layer is not unowned: open PRs already
cover the reactor timeout collection, response-header allocation, parser field
lookup and speculative keep-alive reads. Other tempting shortcuts change
observable behavior or lack a demonstrated large whole-request effect. This
does not establish that no further work is avoidable. No duplicate branch,
PR-queue item, upstream PR, issue or comment was created. Sol/Astra have no
candidate head to review.

## Pins and scope

* Puma main: [`c0df0c19dde943c3f5c25cd67caa984dfa84e3da`](https://github.com/puma/puma/commit/c0df0c19dde943c3f5c25cd67caa984dfa84e3da).
* Latest RubyGems release, **8.0.2**: tag `v8.0.2`, commit
  [`8085b75e79e3f7f1a96e5b488d74a71f62edd24d`](https://github.com/puma/puma/commit/8085b75e79e3f7f1a96e5b488d74a71f62edd24d).
  GitHub's `releases/latest` instead returned 7.2.1; the RubyGems latest-version
  API and repository tags were checked rather than treating that as current.
* Ruby `4.0.9`, revision `3e93b23afc`, Linux x86-64, interpreter explicitly
  `--disable-yjit`, production reference `--yjit --yjit-perf`.
  Full Ruby source pin:
  [`3e93b23afcec3433f6aecc34b5d832799d754238`](https://github.com/ruby/ruby/commit/3e93b23afcec3433f6aecc34b5d832799d754238).
* Shared Lowrail measurement helpers at
  [`d69ac46c7b8897d037f0cb7618b219619248ea29`](https://github.com/thomasklemm/lowrail/commit/d69ac46c7b8897d037f0cb7618b219619248ea29).
* Rails main [`1e235cee11b0a7aecb189d8837534807626287aa`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa),
  Blog from the existing `real-blog-r4` corpus, prepared through
  `script/census setup --corpus censuspuma --apps blog`. Lowrail is off.
* Trivial apps return a fixed 200, two ordinary Hash headers, and one body
  String in an Array: **64 bytes** and **51,200 bytes**. Blog serves `/articles`.
  There is no access logger or reverse proxy in front of Puma.
* Rack **3.2.8** for the trivial apps and wire probes; Blog's pinned bundle
  resolves Rack **3.2.7**, sqlite3 **2.10.1** and JSON **3.1.0**. Each comparison
  keeps that workload's bundle unchanged. Both workloads use nio4r **2.7.5**.

Both Puma builds are compiled locally with the same Ruby. The harness checks
the loaded Puma Ruby/native feature paths, not just `PUMA_VERSION` (main also
reports 8.0.2). One process has one or four worker threads and one or four client
connections respectively. Fresh traffic sends `Connection: close`; persistent
traffic retains connections subject to Puma's unchanged default keep-alive
limit. Connections are separate between warmup and measured batches.

## What happens per request

### Accept, reactor and pool

`Server#handle_servers` accepts a socket and queues a `Client` in the thread
pool. `process_client` first tries `eagerly_finish`, a zero-time readability
poll followed by nonblocking reads. Incomplete requests move to the reactor:
`Reactor#add` pushes onto a Queue and wakes nio4r's selector. The reactor reads
and parses until the request is ready, then puts the client back in the pool.
The pool locks its work Array and signals a condition variable; the worker
shifts a client and invokes `process_client` again.

After a keep-alive response, `Client#reset` resets the parser and StringIO and
duplicates the protocol env. Pipelined bytes already in the buffer are parsed
directly. Otherwise Puma polls for the next request immediately. A ready
request may run inline when other threads are waiting; otherwise it is
requeued, or parked in the reactor with the persistent timeout. This is why
single-thread and multi-thread paths need separate observations. It is not
correct to charge every request an accept or a complete reactor round trip.

The reactor currently keeps timeouts in an Array: deletion scans, registration
sorts the collection, and `take_while` allocates on selector wakeups. This can
matter with many idle connections, but is precisely the subject of open
[Puma 4047](https://github.com/puma/puma/pull/4047). The present matrix has at
most four active client connections; it does not price a large idle pool.

### Parser and env

The Ragel C parser normalizes field names in the input buffer, searches 36
common headers linearly, and uses pre-interned UTF-8 keys. Uncommon keys use
`rb_enc_interned_str` too. Header values are fresh mutable binary Strings;
duplicate headers append `", "` and the next value. Request method, protocol,
URI and path also get fresh Strings. These are not all redundant copies:
middleware can mutate env values, and the parser's input-buffer mutation is
itself under discussion in [4060](https://github.com/puma/puma/pull/4060).

`Client#normalize_env` derives host/port, remote address, path, scheme, hijack
callback and Rack input. `req_env_post_parse` scans the entire env to normalize
underscore aliases without allowing them to replace proxy-managed headers,
then installs reply/response-finished arrays. That security-related scan is a
possible future attribution target, not permission to remove it. Each request
needs its own env: applications may retain it after return.

An independent app-entry probe with only Host/Connection request headers sees
**28 entries on release / 29 on main**, **992 bytes** of shallow Hash storage in
each, with every key frozen. This is
not the retained size of the referenced values. Method/protocol values are
mutable in both. Main adds the connection-closed callback. Header-key freezing
is already implemented, notably in byroot's
[3754](https://github.com/puma/puma/pull/3754) and
[3825](https://github.com/puma/puma/pull/3825); it is not a new candidate.

Header reads call `read_nonblock(65_536)` without an output buffer, unlike
body reads. Ruby 4.0.9's `rsock_read_nonblock` allocates that String before
calling `recv`; passing a reusable String avoids the new String but retains
its capacity. A separate Socket.pair/ObjectSpace check reads 31 bytes with a
65,536-byte limit: the reusable String grows from **40 to 65,577 bytes** of
shallow storage. This is an allocation-capacity observation, not RSS or a
Puma CPU saving. Reuse must also preserve partial-header accumulation,
pipelined leftovers and app-retained request bodies; blindly passing
`@read_buffer` overwrites `@buffer` when they alias. Smaller header read limits
change batching and timeout/fairness boundaries. No large whole-request gain
without that memory/lifetime tradeoff was demonstrated, so no patch is built.

### Response, headers and writes

The current owner is `Puma::Response` in `lib/puma/response.rb`, not the former
`Puma::Request`. `str_headers` checks illegal names/values, downcases each key
once, handles content length, transfer encoding and hijack specially, splits
newline String values, and serializes Array values separately. `Rack::Headers`
uses the same enumeration path: there is no special no-normalization fast
path. A class check alone would not establish that user keys or iteration
cannot be overridden.

Downcasing twice was already fixed in
[3874](https://github.com/puma/puma/pull/3874). Header allocation work is now
covered by open [4048](https://github.com/puma/puma/pull/4048). An earlier
`Regexp#match?` proposal, [2130](https://github.com/puma/puma/pull/2130), was
declined on its then-supported Rubies and measurements; its old conclusion is
not a Ruby 4 measurement, and neither are the new PR's claims our evidence.

Puma uses a reusable `IOBuffer < StringIO`. A single String body below **256
KiB** is copied into the header buffer and sent together. Thus **both trivial
body sizes already submit headers and body together** to `write_nonblock`,
not as separate header/body writes; partial writes can still require retries.
Larger single bodies use separate header/body writes; Array
bodies buffer to a 512 KiB threshold. Files use a 64 KiB boundary and
`IO.copy_stream` above it. Streaming enumerables have different flush and
chunking behavior; buffering their yields changes when clients see bytes and
when user code resumes.

The network path is `write_nonblock`, with partial-write slicing, writable
waits and a write timeout, **not per-response `IO#syswrite`**. Ruby's buffered
multi-argument `IO#write`/writev cannot be substituted without preserving
partial-write, SSL, scheduler, error and timeout behavior. The old
[writev proposal 2568](https://github.com/puma/puma/pull/2568) was closed;
MSP-Greg reported the StringIO-buffer approach faster in that investigation,
leading to [2896](https://github.com/puma/puma/pull/2896). That is historical
context, not a current comparative benchmark. `syswrite` on main is used for
the server's control pipe after a shutdown deadlock fix, not as HTTP buffering.

### Socket state and packetization

On Linux, normal handling calls `closed_socket?` before the app and before
writing its response, using `TCP_INFO`. It also enables/disables `TCP_CORK`
around response output. The second state check is after arbitrary app code;
deleting it is not exact just because ordinary clients remain connected.
Skipping corking changes packetization/backpressure and needs more evidence
than a syscall count. Neither is a candidate built here.

## Measurements and admission limits

The [receipt](../../bench/upstream/puma_cpu/results.json) retains per-window
request denominators, CPU, instructions, allocations, GC counts, actual heap
capacities, JIT deltas, client pacing diagnostics and raw-file fingerprints.
Private raw profiles, logs and corpus state stay in `.lowrail/private/puma-cpu/`.

There are **352 complete windows / 140 same-base pairs**, plus the failed
Valgrind attempt described below. Coverage is 128 native, 84 Callgrind,
60 perf, 60 strace and 20 worker-stack windows. Native and Callgrind have A/AA
in every completed cell; perf and strace have the full 48-cell A matrix and
12 one-thread/keep AA controls each. Worker stacks cover one-thread/keep,
both pins and trivial modes plus interpreter Blog, A/AA. No high-idle-connection,
TLS, cluster, scheduler or streaming-body performance cohort is claimed.

The baseline matrix has both builds × three apps × interpreter/YJIT × one/four
threads × keep-alive/fresh connections, each with independent A/AA processes.
These are **single diagnostic pairs**, not a six-round confidence interval or
an admission under the finite ±0.1% request protocol. No main-versus-release
speed claim follows. Native windows use process CPU clocks, not elapsed time;
instrumented CPU clocks are never presented as native request cost. Boot and
warmup are outside every window. The client runs in another process.
The batch ends when the client has read N complete response bodies. This is
not a certificate that the last worker callback or reactor EOF cleanup has
finished; no end-tail audit or zero-work subtraction is supplied. That is
another reason these observations cannot admit a whole-request saving.

Five heap floors and preparation come from `HeapWindows.prepare_heap`, with
actual before/after capacities recorded. GC remains enabled. Whole-process
Callgrind client dumps count all server threads and exclude kernel execution;
the selected worker's Ruby-stack sampler is a separate attribution run, not
the total-server denominator. It starts on the first worker handoff and does
not include work on the acceptor or reactor. No GC-excluded price is claimed.
YJIT's compilation/invalidation/code-GC deltas are retained; a non-flat window
cannot establish a YJIT performance result. No failed pair is filtered out.

The initial native target is 1,000 requests/s, with late dispatches recorded.
Blog cannot sustain that target with the serial client configurations here:
those are response-limited diagnostics, not a fixed-realized-rate load or a
throughput measurement. Neither target rate nor instruction execution under
Valgrind is a throughput result. Hardware `instructions`/`cycles` remain
unavailable in this orb; perf's software `cpu-clock` supplies native/kernel
attribution, with the stack-map's incomplete-native-unwind limitation.
Tools are the existing **Valgrind 3.19.0 with the 512 MiB brk patch**,
**perf 6.1.190**, **strace 6.1**, GCC **12.2.0**, Linux **6.1.189+**, x86-64.

### Native CPU and allocations

Selected **one-thread, keep-alive A windows**, not accepted prices. The A/A
column is the second independent same-base process relative to the first,
not a change made to Puma. Trivial windows have 2,000 requests at a target of
1,000/s; the separately labeled Blog low-rate windows have 500 at 100/s.

| Build | App/body | YJIT process CPU, µs/request | Same-base A/A | Objects/request |
|---|---|---:|---:|---:|
| Release | 64 B | 187.48 | −6.82% | 46.03 |
| Main | 64 B | 180.48 | −4.34% | 47.03 |
| Release | 50 KiB | 188.32 | +3.54% | 46.03 |
| Main | 50 KiB | 211.67 | −1.20% | 47.03 |
| Release | Blog, 100/s target | 1,834.26 | −3.36% | 1,842.19 |
| Main | Blog, 100/s target | 1,843.90 | −3.12% | 1,843.32 |

The full native receipt has **128 windows / 64 A/A pairs**: the original
48-cell matrix twice, plus the lower-rate Blog matrix twice. A/A changes range
from **−23.28% to +16.39%**. **32/64 YJIT windows are non-flat**, and **all 64
Blog windows grow at least one heap pool during measurement**. For example,
main's one-thread YJIT/keep low-rate A grows the 160-byte pool from 100,976 to
151,668 slots. Merely setting initial heap floors did not certify these Blog
windows. There is no fixed-heap, JIT-flat, confidence-interval admission here,
and no release/main or interpreter/YJIT speed comparison is inferred.

Warmup is unpaced, unlike the measured client schedule; it does not by itself
establish that the paced reactor paths are warm. Actual endpoint counters,
not the warmup's three-flat observation, decide the JIT-flat flag. A single
client's first dispatch is necessarily counted late by the zero-slack pacing
check; 1/500 late in the selected low-rate Blog windows is not the original
2,000/2,000 response-limited result. All late counts remain in the receipt.

### Whole-server instructions

One-thread keep-alive A windows, **100 requests**, client target 20/s. Ir
includes all server user-space threads, VM and native callees, not the kernel.
These are counts, not CPU time. Each A/A entry is still only one diagnostic
pair; none is promoted to a certified price just because its point delta is
small. The selected windows below collect no GC; there is no separate
GC-excluded cohort or zero-work seam subtraction.

| Build | App/body | Interpreter Ir/request | A/A | YJIT Ir/request | A/A |
|---|---|---:|---:|---:|---:|
| Release | 64 B | 268,709 | +0.256% | 211,106 | +0.155% |
| Main | 64 B | 274,640 | +0.474% | 214,346 | −0.353% |
| Release | 50 KiB | 321,156 | −0.039% | 262,926 | −0.321% |
| Main | 50 KiB | 326,601 | −0.391% | 265,736 | −0.001% |
| Release | Blog | 9,188,741 | −0.045% | 5,192,708 | −0.044% |
| Main | Blog | 9,198,880 | +0.012% | unmeasured | unmeasured |

The planned 96-window instruction matrix retains **84 complete windows**.
Release/Blog/YJIT/four-thread/keep A failed before producing a result:
Valgrind's AMD64 decoder received SIGSEGV in `dis_ESC_NONE` / `disInstr_AMD64`,
fault address `0x3FF0B000`. The guest clients then saw EOF. This is an internal
Valgrind failure, not a Puma or Ruby correctness result. The failed attempt and
log hashes are in the receipt. The other **11 unattempted YJIT Blog arms** were
stopped, including main, rather than collecting until the cohort looked green.
The worker-stack sampler also does not attempt YJIT Blog after that failure.
Native perf covers YJIT Blog independently. The selected release/YJIT Blog
counts above remain diagnostic surviving observations, not a rescued cohort.

### Native and kernel ownership

Perf uses `cpu-clock` at 997 Hz, all server threads, DWARF stack depth 16,384
bytes and Ruby's YJIT maps, with acknowledged FIFO window boundaries. These
are exclusive CPU-sample percentages, not instructions or removable budgets.
The nearest recognizable JIT frame owns ordinary C callees; GC and kernel
leaves have their own buckets. VM/native-unresolved includes incomplete
unwinds. Inclusive caller counts in the receipt overlap and must not be added.

One-thread, keep-alive YJIT, **2,000 requests** per window: trivial apps target
1,000/s, Blog targets 100/s. Each cell below retains **A / AA** independently.

| Build | App/body | Samples A / AA | Puma % A / AA | Kernel % A / AA | VM/native unresolved % A / AA |
|---|---|---:|---:|---:|---:|
| Release | 64 B | 347 / 366 | 25.07 / 24.32 | 46.97 / 48.36 | 16.43 / 14.75 |
| Main | 64 B | 431 / 462 | 24.13 / 25.54 | 47.10 / 44.16 | 18.79 / 19.26 |
| Release | 50 KiB | 442 / 458 | 29.41 / 24.24 | 37.33 / 37.99 | 13.12 / 18.12 |
| Main | 50 KiB | 444 / 418 | 28.15 / 27.75 | 40.54 / 37.80 | 13.96 / 16.51 |
| Release | Blog | 3,659 / 3,596 | 9.48 / 9.87 | 9.65 / 8.84 | 16.40 / 16.32 |
| Main | Blog | 3,780 / 3,777 | 7.86 / 8.50 | 9.10 / 8.08 | 16.64 / 16.44 |

This independently sees the stack-map's roughly 8–11% Puma region in Blog,
not evidence of a main/release speed difference. Across all 60 profiles,
325–7,282 samples/window and zero reported lost samples remain; **12/30 YJIT
windows are non-flat** and **20/60 grow a heap pool**. The 12 perf process-CPU
A/A point deltas range from **−4.68% to +18.50%**. Instrumented process CPU
is not a native price or a certification of these partitions.

Kernel leaves prominently include `finish_task_switch` and spin-unlock paths:
this bucket includes scheduling, networking, interrupts and profiling work,
not just time in HTTP syscalls. Large-body profiles also expose libc
`memmove`/`memset`, consistent with the already-buffered response path. Neither
observation establishes an exact operation that can be deleted.

### Syscalls per request

`strace -f -c`, attached after warmup and detached by the client, counts all
server threads. **500 requests**, target **100/s**. Counts include the small
control/endpoint envelope and expected errors such as EAGAIN/EEXIST, retained
in the receipt. Strace's accumulated syscall seconds include blocking and
ptrace disturbance; they are **not CPU/request**. Its process-CPU A/A point
deltas range from −10.99% to +7.48%; no saving is priced with them.

| Build | App/body | Keep total calls/request A / AA | Fresh total A | HTTP `sendto`/request, all three |
|---|---|---:|---:|---:|
| Release | 64 B | 20.888 / 20.888 | 19.060 | 1.000 |
| Main | 64 B | 21.346 / 20.846 | 19.054 | 1.000 |
| Release | 50 KiB | 21.278 / 20.310 | 19.058 | 1.000 |
| Main | 50 KiB | 21.396 / 21.100 | 19.070 | 1.000 |
| Release | Blog | 43.858 / 44.690 | 42.922 | 1.000 |
| Main | Blog | 45.718 / 45.266 | 42.798 | 1.000 |

Main/64 B/keep A has **2.000 getsockopt + 2.000 setsockopt**, **1.002
recvfrom**, **1.002 ppoll**, **3.200 epoll_wait**, **1.000 epoll_ctl**, **5.100
futex**, **3.002 read** and **1.998 write** per request. Accept and close each
cost 0.002/request here (one measured connection); fresh traffic has one each.
Fresh traffic avoids some reactor notification handoffs on these paced paths;
its lower server-PID call total does not make it cheaper end to end. The
client's connect/close and other processes are outside this denominator.

All six selected A/AA keep pairs have two TCP_INFO queries and two cork option
changes per response. There are **two writev calls in an entire 500-request
window**, not two per response. A separate `strace -f -yy` wire probe identifies
HTTP output as TCP `sendto(..., MSG_DONTWAIT, ...)` and notification writes as
one-byte pipe writes. Both fixed bodies already have one HTTP send per
response in these count windows; `write` totals cannot be read as extra HTTP
body writes. Blog additionally has getrandom, file/locking and clock calls;
whole-stack syscall totals must not all be assigned to Puma.

### Worker instruction attribution

The separate census sampler follows the selected worker from its first
measured handoff, **100 requests at 20/s**, excluding its handler instructions.
It omits acceptor/reactor work and the kernel. For main/64 B/YJIT A, nearest
Ruby owners include `closed_socket?` **176/911 signals (19.32%)** and
`str_headers` **161/911 (17.67%)**. For main/50 KiB/YJIT A,
`fast_write_response` has **664/1,479 (44.90%)**. These are worker instruction
shares including C callees charged to their Ruby caller, **not whole-request
CPU percentages**, and do not make the socket checks or copy removable.

In interpreter Blog, Puma's exclusive worker share is **3,869/111,829
(3.46%) release**, **3,983/111,996 (3.56%) main**; `str_headers` alone has
1,515 and 1,530 signals respectively (about 1.36%). Worker-stack A/A Ir point
deltas range from −1.81% to +5.25%. All eight sampled YJIT windows are non-flat;
the 20 worker windows keep heap capacities unchanged and report no dropped,
empty or truncated samples. The receipt retains handler/lag counters. This
attribution locates work, not a new steady-state instruction price.

## Overlap and candidate decision

The canonical main source, open/closed PR search, recent commits and maintainer
work were checked before proposing a patch. Especially relevant:

| Work | Existing owner / disposition |
|---|---|
| Reactor timeout scanning/sorting | Open [4047](https://github.com/puma/puma/pull/4047); no duplicate |
| Response single-line splitting and regexp checks | Open [4048](https://github.com/puma/puma/pull/4048); no duplicate |
| C common-header lookup | Open [4049](https://github.com/puma/puma/pull/4049); no duplicate |
| Intern method/protocol values | Open [4050](https://github.com/puma/puma/pull/4050); additionally fails this task's mutable-value exactness bar |
| Keep-alive speculative wait | Open [4051](https://github.com/puma/puma/pull/4051); changes waiting/fairness, not an exact deletion |
| Response restructuring | schneems' open [3803](https://github.com/puma/puma/pull/3803), last updated 2025-11-04; historical overlap, not evidence of current activity |
| Large file Content-Length handling | nateberkopec's open [4012](https://github.com/puma/puma/pull/4012); correctness work, not this bet |
| Shutdown/draining | dentarg's merged [4001](https://github.com/puma/puma/pull/4001), current pool/notify fixes; preserve behavior |

Recent MSP-Greg work includes socket/test stabilization, the existing buffering
path and parser/env organization; schneems already optimized scheme selection
in [3732](https://github.com/puma/puma/pull/3732). Nate's current threat model
explicitly relies on Rack conformance. This is a maintained layer, not a vacant
space in which every allocation should become another PR.

The most concrete removable-work leads are **reactor timeout bookkeeping** and
**response-header serialization**, but both already have concrete open work.
No exact, large, independent third operation was isolated. Frozen env values,
reused env Hashes, removed socket-state checks and changed streaming buffering
are rejected on semantics; tiny unpack/branch/allocation reductions are not
built without whole-request evidence. Falcon/Pitchfork were not added: the
costs are already located within Puma, and comparing server architectures would
not establish that a particular Puma operation is redundant.

## Independent wire checks and reproduction

`probe.rb` constructs expected bytes independently of Puma's serializer. Both
pins pass fixed bytes/close, HTTP/1.0, pipelined requests, slow header fragments,
header-timeout silent close versus body-timeout 408, a slow reader's partial
response/write-timeout close, exact 80 KiB value and
80 KiB + 1 rejection, HEAD, Rack::Headers/newline/Array/invalid headers,
stream chunk bytes/close, unframed HTTP/1.0 streaming, full/partial hijack, app
errors, chunked request input and asymmetric concurrent fiber-local values
on eight distinct per-request fibers with four worker threads: **21 assertions
per pin**, run with YJIT. Source-path checks and full heads identify both builds.
The initial slow-reader probe's five-second harness budget was corrected:
Puma uses the ten-second `WRITE_TIMEOUT` constant, not a `write_timeout` option.
No Puma timeout was changed to make the check pass.

The mixed `Connection: Keep-Alive, ClOsE` probe intentionally records a
main/release difference: release serves two pipelined requests; main closes
after one, matching its already-merged
[4031](https://github.com/puma/puma/pull/4031). It is not silently normalized
away or presented as a newly found performance bug. Fixed and response-header
wire fingerprints match across the two pins.

Puma's own suites were run against the unmodified builds with Ruby 4.0.9/YJIT:

| Pin | Command, in that checkout | Result |
|---|---|---|
| Main | `ulimit -n 4096; RUBYOPT=--yjit bundle exec rake test TESTOPTS=--seed=27488` | 983 runs, 2,985 assertions, 0 failures, 0 errors, 6 skips |
| Release | `ulimit -n 4096; RUBYOPT=--yjit bundle exec rake test TESTOPTS=--seed=36273` | 840 runs, 2,486 assertions, **1 failure**, 0 errors, 8 skips |

The release failure is `TestExampleCertExpiration#test_certs_not_expired`:
`examples/puma/chain_cert/cert.crt` expired **2026-09-10**, independently checked
with `openssl x509 -noout -dates`. It was not regenerated or excluded. Initial
full-suite attempts at the orb's soft limit of 1,024 descriptors had two
fork-worker EMFILE errors on both pins and one release restart EPIPE/teardown
timeout. The two main fork tests passed a focused 4,096-limit check, then the
full suites were run once at the same respective seeds with that limit; the
initial failures remain in private logs. No code or skipped-test selection
was changed. The earlier main in-process suite separately passed 800 runs,
2,334 assertions, 0 failures/errors, 4 skips. These are baseline validation,
not performance controls or an exactness certificate for an unbuilt patch.

Adapters are in [bench/upstream/puma_cpu](../../bench/upstream/puma_cpu/), reusing
the existing heap, Callgrind, census and perf infrastructure rather than a new
benchmark framework. Compile each Puma checkout with Ruby 4.0.9 and its own
`bundle exec rake compile`. Prepare Blog with the census command above; select
the built Callgrind from `script/cpu-census build --prefix .../valgrind` and
compile `bench/callgrind.c` against that tool and Ruby. The source-keyed census
sampler is built through `CpuCensus.extension`, as in the stack-map record.

```sh
PUMA_COUNT=2000 PUMA_RATE=1000 bash bench/upstream/puma_cpu/run.sh puma small yjit 1 keep native a
PUMA_COUNT=2000 PUMA_RATE=1000 bash bench/upstream/puma_cpu/run.sh puma small yjit 1 keep native aa
ruby --yjit bench/upstream/puma_cpu/probe.rb "$PWD/.lowrail/private/puma-cpu/puma"
ruby bench/upstream/puma_cpu/export.rb .lowrail/private/puma-cpu bench/upstream/puma_cpu/results.json
```

Use `release` for the tag checkout; `small`, `large`, `blog` for workloads;
`interpreter`/`yjit`; `1`/`4`; `keep`/`fresh`; and the counter named in the
receipt. Output directories must be new. Supervised services use ephemeral
ports. An initial shared-port startup race is preserved in private logs; arms
that never started a server are setup failures, not failed A/A measurements.
There are no replacement measurements for rejected controls.
