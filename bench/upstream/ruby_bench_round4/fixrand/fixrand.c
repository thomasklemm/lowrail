/* LD_PRELOAD control: the getrandom syscall returns a fixed byte stream, so
 * Ruby's hash seed and default Random seed are the same in every process. */
#define _GNU_SOURCE
#include <stdarg.h>
#include <stddef.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <dlfcn.h>
static unsigned long long s = 0x9e3779b97f4a7c15ULL;
static long fill(unsigned char *p, size_t n) {
    for (size_t i = 0; i < n; i++) { s = s * 6364136223846793005ULL + 1442695040888963407ULL; p[i] = s >> 56; }
    return (long)n;
}
ssize_t getrandom(void *buf, size_t n, unsigned int flags) { return fill(buf, n); }
long syscall(long nr, ...) {
    va_list ap; va_start(ap, nr);
    long a[6]; for (int i = 0; i < 6; i++) a[i] = va_arg(ap, long);
    va_end(ap);
    if (nr == SYS_getrandom) return fill((unsigned char *)a[0], (size_t)a[1]);
    static long (*real)(long, ...);
    if (!real) real = dlsym(RTLD_NEXT, "syscall");
    return real(nr, a[0], a[1], a[2], a[3], a[4], a[5]);
}
