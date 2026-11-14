/* LD_PRELOAD shim: getrandom/getentropy return a stream fixed by F1_SEED, so Ruby's hash salt
 * (and with it every AR-table hint) is the same in every run with that seed. Measurement only. */
#define _GNU_SOURCE
#include <stdlib.h>
#include <stdint.h>
#include <sys/types.h>

static uint64_t state;
static int ready;

static uint64_t next(void) {
    if (!ready) { const char *s = getenv("F1_SEED"); state = s ? strtoull(s, 0, 10) * 0x9E3779B97F4A7C15ull + 1 : 1; ready = 1; }
    uint64_t z = (state += 0x9E3779B97F4A7C15ull);
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
    return z ^ (z >> 31);
}

ssize_t getrandom(void *buf, size_t len, unsigned int flags) {
    unsigned char *p = buf;
    for (size_t i = 0; i < len; i++) p[i] = (unsigned char)next();
    return (ssize_t)len;
}

int getentropy(void *buf, size_t len) { getrandom(buf, len, 0); return 0; }
