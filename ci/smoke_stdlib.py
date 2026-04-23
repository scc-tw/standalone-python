#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Cross-version stdlib smoke test for standalone-python.

Exercises the major C extensions and their backing libraries. Compatible
with both Python 2.7 and Python 3.x so CI can run the same script against
every matrix cell.

Exit status: 0 if every section either succeeded or was explicitly
skipped (e.g. `lzma` on 2.7). Non-zero if any unexpected exception.

Run:
    ./python /tmp/smoke_stdlib.py
"""

from __future__ import print_function

import os
import sys
import traceback


_IS_PY3 = sys.version_info[0] >= 3
SECTIONS = []


def section(label):
    def decorator(fn):
        SECTIONS.append((label, fn))
        return fn
    return decorator


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------


@section("version / platform")
def s_version():
    print("  " + sys.version.splitlines()[0])
    print("  executable  : " + sys.executable)
    print("  platform    : " + sys.platform + " / " + os.uname()[4])


@section("ssl (OpenSSL)")
def s_ssl():
    import ssl
    print("  OPENSSL     : " + ssl.OPENSSL_VERSION)
    ctx = ssl.create_default_context()
    assert hasattr(ctx, "check_hostname")
    # If the build is going to fail spectacularly against OpenSSL, it'll
    # usually do it in the context constructor (missing symbols at load).


@section("hashlib (md5/sha1/sha256/sha512)")
def s_hashlib():
    import hashlib
    # Known-answer tests against the empty string so a silently-wrong
    # backend is detectable.
    kats = {
        "md5":    "d41d8cd98f00b204e9800998ecf8427e",
        "sha1":   "da39a3ee5e6b4b0d3255bfef95601890afd80709",
        "sha256": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
        "sha512": ("cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce"
                   "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"),
    }
    for algo, expected in kats.items():
        h = hashlib.new(algo)
        got = h.hexdigest()
        assert got == expected, algo + " wrong: " + got + " != " + expected
    avail = sorted(hashlib.algorithms_available)
    print("  backed      : " + str(len(avail)) + " algorithms via _hashlib")


@section("sqlite3")
def s_sqlite():
    import sqlite3
    conn = sqlite3.connect(":memory:")
    try:
        cur = conn.cursor()
        cur.execute("CREATE TABLE t (k TEXT, v INTEGER)")
        cur.executemany("INSERT INTO t VALUES (?, ?)", [("a", 1), ("b", 2), ("c", 3)])
        cur.execute("SELECT SUM(v) FROM t")
        (total,) = cur.fetchone()
        assert total == 6
    finally:
        conn.close()
    print("  library     : " + sqlite3.sqlite_version)


@section("zlib")
def s_zlib():
    import zlib
    data = b"standalone-python " * 100
    c = zlib.compress(data, 9)
    d = zlib.decompress(c)
    assert d == data
    print("  library     : " + zlib.ZLIB_VERSION +
          ", ratio " + str(len(c)) + "/" + str(len(data)))


@section("bz2")
def s_bz2():
    import bz2
    data = b"The quick brown fox " * 50
    c = bz2.compress(data)
    d = bz2.decompress(c)
    assert d == data


@section("lzma (Py3-only)")
def s_lzma():
    if not _IS_PY3:
        print("  skipped (Py2 has no stdlib _lzma module)")
        return
    import lzma
    data = b"lzma smoke " * 100
    c = lzma.compress(data)
    d = lzma.decompress(c)
    assert d == data


@section("ctypes (libc via dlopen)")
def s_ctypes():
    import ctypes
    libc = ctypes.CDLL(None)  # NULL handle = main program / already-loaded libc
    libc.getpid.restype = ctypes.c_int
    assert libc.getpid() == os.getpid()
    # strlen is a good signal for reaching libc proper
    libc.strlen.argtypes = [ctypes.c_char_p]
    libc.strlen.restype = ctypes.c_size_t
    assert libc.strlen(b"standalone") == 10


@section("curses")
def s_curses():
    # Don't call initscr() — that needs a real tty. Just confirm the C
    # extension loads and exposes module-level symbols. ACS_* / COLS /
    # LINES and friends are populated by initscr() (they come from the
    # terminfo ACS map), so we stick to things that exist at import time.
    import curses
    assert hasattr(curses, "initscr")
    assert hasattr(curses, "color_pair")
    assert hasattr(curses, "error")     # module-level exception class
    assert hasattr(curses, "KEY_UP")    # module-level key constant
    assert hasattr(curses, "A_NORMAL")  # module-level attribute constant
    # panel is a separate extension (_curses_panel); check both.
    import curses.panel
    assert hasattr(curses.panel, "new_panel")


@section("readline")
def s_readline():
    import readline
    assert hasattr(readline, "parse_and_bind")
    assert hasattr(readline, "get_history_length")


@section("socket")
def s_socket():
    import socket
    # Don't require network — just exercise the parsing layers.
    addrs = socket.getaddrinfo("127.0.0.1", 80, 0, socket.SOCK_STREAM)
    assert addrs, "no addrinfo for 127.0.0.1:80"
    # IPv6 parsing
    packed = socket.inet_pton(socket.AF_INET6, "::1")
    assert len(packed) == 16


@section("subprocess (spawn child, check rc + output)")
def s_subprocess():
    import subprocess
    out = subprocess.check_output(
        [sys.executable, "-c", "import sys; sys.stdout.write('42')"]
    )
    assert b"42" in out, "unexpected child output: " + repr(out)


@section("threading (basic Thread run/join)")
def s_threading():
    import threading
    results = []
    t = threading.Thread(target=lambda: results.append("ok"))
    t.start()
    t.join(timeout=2)
    assert not t.is_alive(), "thread still alive after join"
    assert results == ["ok"]


@section("json")
def s_json():
    import json
    s = json.dumps({"a": [1, 2, 3], "b": "standålone"})
    back = json.loads(s)
    assert back["a"] == [1, 2, 3]


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def main():
    failed = []
    for label, fn in SECTIONS:
        print(label + ":")
        try:
            fn()
        except Exception:
            failed.append(label)
            traceback.print_exc()

    print()
    print("=" * 50)
    total = len(SECTIONS)
    passed = total - len(failed)
    print("summary: {0}/{1} passed".format(passed, total))
    if failed:
        print("FAILED: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
