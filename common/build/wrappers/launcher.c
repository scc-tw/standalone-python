/*
 * Static launcher for standalone-python.
 *
 * Replaces the old shell python-wrapper / pip-wrapper. The binary is
 * statically linked against musl and has no PT_INTERP, so it runs on any
 * Linux host regardless of the host libc. It resolves the musl ld.so shipped
 * with the distribution relative to its own location ($ORIGIN/..) and uses
 * `execve(ld_so, ...)` to launch the real python binary — this bypasses the
 * need to patch the real python's ELF .interp to a magic /tmp path.
 *
 * When invoked as `python*`, exec path is: ld.so python-real argv[1..]
 * When invoked as `pip*`,    exec path is: ld.so python-real pip-real argv[1..]
 * (pip-real is the shebang pip script; we run it through python-real directly.)
 */

#define _GNU_SOURCE
#include <dirent.h>
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef MUSL_ARCH
#define MUSL_ARCH "x86_64"
#endif

/* Shipped musl version as `MAJOR.MINOR` (e.g. "1.2"). Baked in at compile time
 * from 3.<pyver>/<arch>/deplib/config.mak so the sitecustomize hook can
 * advertise the right musllinux tag to pip without having to fork ld.so at
 * every Python startup. */
#ifndef MUSL_VERSION
#define MUSL_VERSION "1.2"
#endif

static void die(const char *msg) {
    if (errno)
        fprintf(stderr, "standalone-python launcher: %s: %s\n", msg, strerror(errno));
    else
        fprintf(stderr, "standalone-python launcher: %s\n", msg);
    exit(127);
}

/* -------------------------------------------------------------------------
 * Heap string type.
 *
 * The launcher deals entirely in filesystem paths. PATH_MAX on Linux is
 * advisory (4096 on most distros, 0 or missing on others) and various
 * filesystems return longer paths from readlink/readdir. Rather than sprinkle
 * fixed PATH_MAX stack buffers around, every path lives in a `str` that
 * grows on demand.
 *
 * Ownership: callers own any `str` they fill. The launcher exec's away at
 * the end of main, so nothing here bothers to free — the kernel reclaims.
 * ------------------------------------------------------------------------- */

typedef struct {
    char *data;     /* NUL-terminated; NULL iff cap == 0 */
    size_t len;     /* strlen(data) when data != NULL */
    size_t cap;     /* allocation size of data, including trailing NUL */
} str;

static void *xrealloc(void *p, size_t n) {
    void *r = realloc(p, n);
    if (!r) die("realloc");
    return r;
}

static char *xstrdup(const char *s) {
    char *r = strdup(s);
    if (!r) die("strdup");
    return r;
}

/* Ensure `s->cap >= need`. */
static void str_reserve(str *s, size_t need) {
    if (s->cap >= need) return;
    size_t cap = s->cap ? s->cap : 64;
    while (cap < need) cap *= 2;
    s->data = xrealloc(s->data, cap);
    s->cap = cap;
}

/* Replace s's contents with printf output. */
static void str_setf(str *s, const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);
    if (n < 0) die("vsnprintf");
    str_reserve(s, (size_t)n + 1);
    va_start(ap, fmt);
    vsnprintf(s->data, s->cap, fmt, ap);
    va_end(ap);
    s->len = (size_t)n;
}

/* Replace s's contents with a C string. */
static void str_set(str *s, const char *src) {
    size_t n = strlen(src);
    str_reserve(s, n + 1);
    memcpy(s->data, src, n + 1);
    s->len = n;
}

/* Read a symlink into `s`, growing until it fits. Returns 0 on success,
 * -1 on readlink error. `s` is left in a valid state either way. */
static int str_readlink(str *s, const char *path) {
    str_reserve(s, 256);
    for (;;) {
        ssize_t n = readlink(path, s->data, s->cap);
        if (n < 0) return -1;
        if ((size_t)n < s->cap) {
            s->data[n] = '\0';
            s->len = (size_t)n;
            return 0;
        }
        /* Exact fill means truncation — grow relative to the current cap so
         * a caller-supplied larger buffer still gets doubled. */
        str_reserve(s, s->cap * 2);
    }
}

/* Truncate `s` to its parent directory, in place (POSIX dirname-style,
 * minus the mutation-of-the-input-pointer weirdness). */
static void str_dirname(str *s) {
    if (s->len == 0) return;
    char *slash = strrchr(s->data, '/');
    if (!slash) {
        s->data[0] = '\0';
        s->len = 0;
        return;
    }
    if (slash == s->data) {
        s->data[1] = '\0';   /* keep the leading '/' for root */
        s->len = 1;
    } else {
        *slash = '\0';
        s->len = (size_t)(slash - s->data);
    }
}

/* Last path component of `s`. Returned pointer aliases into `s->data`. */
static const char *path_basename(const char *p) {
    if (!p) return "";
    const char *slash = strrchr(p, '/');
    return slash ? slash + 1 : p;
}

/* -------------------------------------------------------------------------
 * Real-binary lookup
 * ------------------------------------------------------------------------- */

/* Find the most-specific entry in `dir` whose name starts with `prefix` and
 * ends with `-real`. Among multiple candidates (e.g. `python3-real` and
 * `python3.12-real`) the longest name wins so version-suffixed binaries are
 * preferred. readdir order is filesystem-dependent, so scanning to completion
 * makes the selection deterministic.
 *
 * On success, writes the full path to `out` and returns 0. On no match
 * returns -1 and leaves `out` untouched. */
static int find_real_bin(const char *dir, const char *prefix, str *out) {
    DIR *d = opendir(dir);
    if (!d) return -1;
    size_t plen = strlen(prefix);
    char *best = NULL;
    size_t best_len = 0;
    struct dirent *e;
    while ((e = readdir(d)) != NULL) {
        const char *n = e->d_name;
        size_t nlen = strlen(n);
        if (nlen < plen + 5) continue;
        if (strncmp(n, prefix, plen) != 0) continue;
        if (strcmp(n + nlen - 5, "-real") != 0) continue;
        if (nlen <= best_len) continue;
        free(best);
        best = xstrdup(n);
        best_len = nlen;
    }
    closedir(d);
    if (!best) return -1;
    str_setf(out, "%s/%s", dir, best);
    free(best);
    return 0;
}

/* ------------------------------------------------------------------------- */

int main(int argc, char **argv) {
    /* Resolve our own absolute path so the install is relocatable. */
    str exe = {0};
    if (str_readlink(&exe, "/proc/self/exe") != 0) die("readlink /proc/self/exe");

    /* exe ≈ /opt/python/bin/python3  →  bin_dir = /opt/python/bin */
    str bin_dir = {0};
    str_set(&bin_dir, exe.data);
    str_dirname(&bin_dir);

    /* prefix = /opt/python */
    str prefix = {0};
    str_set(&prefix, bin_dir.data);
    str_dirname(&prefix);

    /* Dispatch on argv[0] basename: pythonX -> python, pipX -> pip. */
    const char *argv0 = argv[0] ? argv[0] : "python";
    const char *argv0_base = path_basename(argv0);

    /* Match exactly `pip`, `pip2`, `pip3`, or `pip<major>.<anything>`.
     * Arbitrary names that merely share a `pipN` prefix (e.g. `pip3-wrapper`)
     * are NOT treated as pip — they'd be surprising and we'd fail to find
     * a matching pip*-real anyway. */
    int is_pip = strcmp(argv0_base, "pip") == 0
              || strcmp(argv0_base, "pip2") == 0
              || strcmp(argv0_base, "pip3") == 0
              || strncmp(argv0_base, "pip2.", 5) == 0
              || strncmp(argv0_base, "pip3.", 5) == 0;

    /* Locate the real binaries. Python is always needed; pip additionally. */
    str python_real = {0};
    if (find_real_bin(bin_dir.data, "python", &python_real) != 0)
        die("could not locate python*-real in bin dir");

    str pip_real = {0};
    if (is_pip && find_real_bin(bin_dir.data, "pip", &pip_real) != 0)
        die("could not locate pip*-real in bin dir");

    /* Shipped musl dynamic linker. */
    str ld_so = {0};
    str_setf(&ld_so, "%s/shared_libraries/lib/ld-musl-%s.so.1", prefix.data, MUSL_ARCH);
    if (access(ld_so.data, X_OK) != 0) die(ld_so.data);

    /* Python derives sys.executable from argv[0]. For pip invocations we must
     * pass the python launcher path (not the pip launcher path) so that pip's
     * build-isolation subprocess calls — which spawn [sys.executable,
     * __pip_runner__, ...] — go through the python dispatch instead of re-
     * entering pip and failing with "unknown command __pip-runner__.py".
     *
     * Derive the launcher name from python_real's basename so the same
     * binary works for Python 2 and Python 3 installs: `python3.12-real`
     * → `python3`, `python2.7-real` → `python2`. The 7th byte (after the
     * literal "python") is the major-version digit. */
    const char *python_real_base = path_basename(python_real.data);
    char python_major = '3';
    if (strncmp(python_real_base, "python", 6) == 0
            && python_real_base[6] >= '2' && python_real_base[6] <= '9') {
        python_major = python_real_base[6];
    }
    str python_launcher = {0};
    str_setf(&python_launcher, "%s/python%c", bin_dir.data, python_major);

    /* Build new argv:
     *   python case: ld_so --argv0 <orig_argv0>      python_real           <argv[1..]>
     *   pip case:    ld_so --argv0 <python_launcher> python_real pip_real  <argv[1..]>
     *
     * --argv0 is supported by musl >= 1.2.0 (we ship 1.2.x). In the python
     * case it preserves the user-visible argv[0] so `ps` and sys.argv[0] look
     * right. In the pip case sys.argv[0] is set by Python from the script
     * argument (pip_real), so overriding argv0 here only redirects
     * sys.executable. */
    int extra = is_pip ? 5 : 4;  /* ld, --argv0, name, real[, pip_real] */
    char **nav = calloc((size_t)(argc + extra), sizeof(char *));
    if (!nav) die("calloc");

    int i = 0;
    nav[i++] = ld_so.data;
    nav[i++] = "--argv0";
    nav[i++] = is_pip ? python_launcher.data : (char *)argv0;
    nav[i++] = python_real.data;
    if (is_pip) nav[i++] = pip_real.data;
    for (int k = 1; k < argc; k++) nav[i++] = argv[k];
    nav[i] = NULL;

    /* Intentionally do NOT set PYTHONHOME here. Python's getpath logic finds
     * the stdlib from argv[0]'s location tree just fine, and setting
     * PYTHONHOME overrides pyvenv.cfg — which would break every venv
     * created on top of this install (sys.prefix would collapse back to the
     * base install, and pip-in-venv would write into the base site-packages). */

    /* Hand the sitecustomize hook the info it needs to make pip/packaging
     * emit `musllinux_<MAJOR>_<MINOR>_<arch>` wheel tags. Without this,
     * packaging.tags falls back to ELF PT_INTERP parsing of sys.executable
     * — which on a static launcher returns nothing, so pip resolves plain
     * linux_x86_64 wheels and ends up loading glibc-built binaries (which
     * fail to relocate against our musl runtime with e.g. "mallinfo: symbol
     * not found"). Both values are $ORIGIN-relative / compile-time
     * constants, so the install stays relocatable. */
    setenv("_STANDALONE_PYTHON_MUSL_LD", ld_so.data, 1);
    setenv("_STANDALONE_PYTHON_MUSL_VERSION", MUSL_VERSION, 1);

    execv(ld_so.data, nav);
    die("execv");
    return 127;
}
