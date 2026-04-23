#!/usr/bin/env python3
"""psutil compatibility smoke test for standalone-python.

Exercises the major surface areas that touch platform-specific code
paths: /proc parsing, libc wrappers via ctypes, subprocess spawn, socket
enumeration, and the loadable _psutil_linux / _psutil_posix C extensions.
A successful run means the musl runtime can satisfy every symbol psutil
links against, and /proc is visible and parseable.

Exit status: 0 if every section either succeeded or was explicitly
skipped (e.g. sensors on a bare container). Non-zero if any section
raised an unexpected exception.

Run:
    ./python3 ci/smoke_psutil.py
"""

import os
import socket
import sys
import time
import traceback


# (section label, callable). Each callable prints its findings. Wrapping
# them as lambdas defers work until we actually enter the section — so a
# failing early import doesn't hide later sections.
SECTIONS = []


def section(label):
    def _decorator(fn):
        SECTIONS.append((label, fn))
        return fn
    return _decorator


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------


@section("version / build")
def s_version():
    import psutil
    print(f"psutil   {psutil.__version__}")
    print(f"PROCFS   {psutil.PROCFS_PATH}")
    print(f"python   {sys.version.splitlines()[0]}")
    print(f"platform {sys.platform} {os.uname().machine}")


@section("cpu")
def s_cpu():
    import psutil
    print(f"logical  : {psutil.cpu_count()}")
    print(f"physical : {psutil.cpu_count(logical=False)}")
    print(f"percent  : {psutil.cpu_percent(interval=0.5, percpu=True)}")
    print(f"times    : {psutil.cpu_times()}")
    print(f"freq     : {psutil.cpu_freq()}")
    print(f"stats    : {psutil.cpu_stats()}")
    try:
        print(f"loadavg  : {psutil.getloadavg()}")
    except (OSError, AttributeError) as e:
        print(f"loadavg  : unavailable ({e})")


@section("memory")
def s_memory():
    import psutil
    print(f"virtual  : {psutil.virtual_memory()}")
    print(f"swap     : {psutil.swap_memory()}")


@section("disk")
def s_disk():
    import psutil
    parts = psutil.disk_partitions(all=False)
    print(f"parts    : {len(parts)} partitions")
    for p in parts[:3]:
        print(f"           {p}")
    print(f"usage /  : {psutil.disk_usage('/')}")
    io = psutil.disk_io_counters(perdisk=False)
    print(f"io       : {io}")


@section("network")
def s_network():
    import psutil
    print(f"io       : {psutil.net_io_counters()}")
    addrs = psutil.net_if_addrs()
    print(f"if_addrs : {list(addrs)}")
    stats = psutil.net_if_stats()
    print(f"if_stats : {list(stats)}")
    for kind in ("inet", "inet4", "tcp", "udp"):
        try:
            conns = psutil.net_connections(kind=kind)
            print(f"conns {kind:5}: {len(conns)}")
        except (psutil.AccessDenied, PermissionError) as e:
            print(f"conns {kind:5}: access denied ({e})")


@section("sensors (optional)")
def s_sensors():
    import psutil
    temps = psutil.sensors_temperatures()
    print(f"temps    : {temps or 'n/a (no /sys/class/hwmon sensors)'}")
    fans = psutil.sensors_fans()
    print(f"fans     : {fans or 'n/a'}")
    print(f"battery  : {psutil.sensors_battery()}")


@section("system")
def s_system():
    import psutil
    print(f"boot     : {time.ctime(psutil.boot_time())}")
    users = psutil.users()
    print(f"users    : {len(users)} logged in")
    for u in users[:3]:
        print(f"           {u}")


@section("current process")
def s_current_process():
    import psutil
    p = psutil.Process(os.getpid())
    print(f"pid      : {p.pid}")
    print(f"name     : {p.name()}")
    print(f"exe      : {p.exe()}")
    print(f"cwd      : {p.cwd()}")
    print(f"cmdline  : {p.cmdline()}")
    print(f"status   : {p.status()}")
    print(f"username : {p.username()}")
    print(f"created  : {time.ctime(p.create_time())}")
    print(f"threads  : {p.num_threads()}")
    print(f"nice     : {p.nice()}")
    print(f"ionice   : {p.ionice()}")
    print(f"num_fds  : {p.num_fds()}")
    print(f"mem_info : {p.memory_info()}")
    print(f"mem_full : {p.memory_full_info()}")
    print(f"cpu_times: {p.cpu_times()}")
    opened = p.open_files()
    print(f"open_fds : {len(opened)} open files")
    env = p.environ()
    print(f"environ  : {len(env)} entries")


@section("process iteration")
def s_process_iter():
    import psutil
    rows = 0
    for proc in psutil.process_iter(["pid", "name", "username", "memory_info"]):
        rows += 1
        if rows <= 5:
            print(f"           {proc.info}")
    print(f"iterated : {rows} processes")


@section("spawn + monitor child")
def s_spawn():
    import psutil
    child = psutil.Popen(
        [sys.executable, "-c", "import time; time.sleep(1)"],
        stdout=None, stderr=None,
    )
    print(f"child pid: {child.pid}")
    print(f"cmdline  : {child.cmdline()}")
    rc = child.wait(timeout=5)
    print(f"exit rc  : {rc}")
    assert rc == 0, f"unexpected child exit: {rc}"


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def main():
    passed = failed = 0
    for label, fn in SECTIONS:
        print(f"\n=== {label} ===")
        try:
            fn()
        except Exception:
            failed += 1
            traceback.print_exc()
        else:
            passed += 1

    print("\n" + "=" * 40)
    print(f"summary: {passed} passed, {failed} failed of {len(SECTIONS)} sections")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
