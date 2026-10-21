# Bet H: boot image and worker memory

Exploration on `thomasklemm/boot-image`, Ruby 4.0.7 / Rails 8.1.4.
No application code/config changes and no runtime-gem change. Results below
are native boot/RSS screens, not request-throughput or instruction claims.

## Experiments and stop rules

1. Plain native boot, warm Bootsnap, current Lowrail default delivery, and a
   packed whole-boot ISeq image. Measure process start through completed first
   Rack request and RSS after ten more requests plus full GC. Capture is a
   real production eager boot, not speculative constant loading.
2. Record feature order, non-autoloading constants and app method metadata
   independently of timing. Responses alone do not establish exactness.
3. Fork the warmed app after full GC, then compare ordinary fork,
   `GC.compact`, and `GC.compact` + `Process.warmup`. Report PSS and private
   dirty pages as well as RSS: RSS double-counts shared pages.

The packed-image probe is **research only**, outside the gem. It stores
native top-level ISeqs observed at `translate`, source digests, Ruby identity,
entry gem versions/paths, load path and compiler options. It validates all
sources before activation and each source again when used. It retains MRI's
require machinery; it is not a zero-stat or zero-path-search implementation.
Changed entry facts or sources fall through to originals. Its Marshal image
is trusted local build output, never an untrusted input format.

This intentionally tests the cheap part before expanding scope. A startup
digest does not certify a file changed later in boot; a recorded require
graph does not authorize suppressing callbacks or eager execution; a
Zeitwerk map must not move autoloads earlier. Attribute generation and
literal freezing can change observable methods/literals. None is enabled
by default or admitted to main by a boot-time win alone.

Reproduction entry point: `bench/experiments/boot_image.rb run CONFIG OUTPUT`.
Private configuration contains disposable credentials/DB paths; only
sanitized measurement exports belong in this repository.

## Results

Corpus setup and native screening in progress. No win or support claim yet.
