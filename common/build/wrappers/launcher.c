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
#include <libgen.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifndef MUSL_ARCH
#define MUSL_ARCH "x86_64"
#endif

static void die(const char *msg) {
    if (errno)
        fprintf(stderr, "standalone-python launcher: %s: %s\n", msg, strerror(errno));
    else
        fprintf(stderr, "standalone-python launcher: %s\n", msg);
    exit(127);
}

/* Find first entry in `dir` whose name starts with `prefix` and ends with `-real`.
 * Writes the full path into `out` (size `len`). Returns 0 on success, -1 on failure. */
static int find_real_bin(const char *dir, const char *prefix, char *out, size_t len) {
    DIR *d = opendir(dir);
    if (!d) return -1;
    size_t plen = strlen(prefix);
    struct dirent *e;
    char match[NAME_MAX + 1] = {0};
    while ((e = readdir(d)) != NULL) {
        const char *n = e->d_name;
        size_t nlen = strlen(n);
        if (nlen < plen + 5) continue;
        if (strncmp(n, prefix, plen) != 0) continue;
        if (strcmp(n + nlen - 5, "-real") != 0) continue;
        strncpy(match, n, sizeof(match) - 1);
        break;
    }
    closedir(d);
    if (match[0] == '\0') return -1;
    int r = snprintf(out, len, "%s/%s", dir, match);
    return (r > 0 && (size_t)r < len) ? 0 : -1;
}

int main(int argc, char **argv) {
    /* Resolve our own absolute path so the install is relocatable. */
    char exe_path[PATH_MAX];
    ssize_t n = readlink("/proc/self/exe", exe_path, sizeof(exe_path) - 1);
    if (n < 0) die("readlink /proc/self/exe");
    exe_path[n] = '\0';

    /* exe_path ≈ /opt/python/bin/python3 */
    char bin_dir[PATH_MAX];
    snprintf(bin_dir, sizeof(bin_dir), "%s", exe_path);
    char *bd = dirname(bin_dir);             /* /opt/python/bin */

    char prefix_buf[PATH_MAX];
    snprintf(prefix_buf, sizeof(prefix_buf), "%s", bd);
    char *prefix = dirname(prefix_buf);      /* /opt/python */

    /* Dispatch on argv[0] basename: pythonX -> python, pipX -> pip. */
    char argv0_buf[PATH_MAX];
    snprintf(argv0_buf, sizeof(argv0_buf), "%s", argv[0] ? argv[0] : "python");
    const char *argv0_base = basename(argv0_buf);

    int is_pip = strcmp(argv0_base, "pip") == 0 || strncmp(argv0_base, "pip3", 4) == 0;

    /* Locate the real binaries. Python is always needed; pip additionally. */
    char python_real[PATH_MAX];
    if (find_real_bin(bd, "python", python_real, sizeof(python_real)) != 0)
        die("could not locate python*-real in bin dir");

    char pip_real[PATH_MAX] = {0};
    if (is_pip && find_real_bin(bd, "pip", pip_real, sizeof(pip_real)) != 0)
        die("could not locate pip*-real in bin dir");

    /* Shipped musl dynamic linker. */
    char ld_so[PATH_MAX];
    if (snprintf(ld_so, sizeof(ld_so), "%s/shared_libraries/lib/ld-musl-%s.so.1",
                 prefix, MUSL_ARCH) >= (int)sizeof(ld_so))
        die("ld.so path too long");

    if (access(ld_so, X_OK) != 0) die(ld_so);

    /* Build new argv:
     *   python case: ld_so --argv0 <orig_argv0> python_real  <argv[1..]>
     *   pip case:    ld_so --argv0 <orig_argv0> python_real pip_real <argv[1..]>
     *
     * --argv0 is supported by musl >= 1.2.0 (we ship 1.2.4). It preserves the
     * user-visible argv[0] so `ps` and sys.argv[0] look right.
     */
    int extra = is_pip ? 5 : 4;  /* ld, --argv0, name, real[, pip_real] */
    char **nav = calloc((size_t)(argc + extra), sizeof(char *));
    if (!nav) die("calloc");

    int i = 0;
    nav[i++] = ld_so;
    nav[i++] = "--argv0";
    nav[i++] = argv[0] ? argv[0] : (char *)argv0_base;
    nav[i++] = python_real;
    if (is_pip) nav[i++] = pip_real;
    for (int k = 1; k < argc; k++) nav[i++] = argv[k];
    nav[i] = NULL;

    /* Help Python locate its stdlib if the user cleared their env. Harmless if
     * already set; setenv(..., 0) only writes when unset. */
    setenv("PYTHONHOME", prefix, 0);

    execv(ld_so, nav);
    die("execv");
    return 127;
}
