/* Disposable interpreter Callgrind control ONLY. Never preload into an app,
 * production process, or timing run: this deliberately destroys randomness.
 * Ruby initializes its private hash salt before Ruby code can seed Random.
 * Holding getrandom bytes fixed makes hash.c's sign normalization comparable.
 * cc -shared -fPIC -O2 jit_literal_kwrest_seed.c -o fixed_seed.so
 */
#include <stddef.h>
#include <string.h>
#include <sys/types.h>

ssize_t getrandom(void *buffer, size_t size, unsigned int flags)
{
    (void)flags;
    memset(buffer, 0x5a, size);
    return (ssize_t)size;
}
