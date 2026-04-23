#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Tkinter / Tcl-Tk smoke test for standalone-python.

Cross-version (Python 2.7 and Python 3.x). Exercises the `_tkinter` C
extension and the shipped Tcl/Tk runtime.

Sections:
  1. import   — `_tkinter` loads, module paths, reported Tcl/Tk versions
  2. tcl      — create a Tcl() interpreter (no display), run commands,
                read `info library` to confirm the shipped Tcl lib tree
                is actually findable at runtime
  3. tk-path  — try `package require Tk` against the Tcl interpreter.
                Needs a display to succeed; without one, at least
                confirms Tcl could find `tk.tcl` (distinguishes a
                *relocation-broken* Tk from a missing-$DISPLAY one).
  4. gui      — only if $DISPLAY is set: Tk() root window + a Label and
                Button, check geometry & widget hierarchy, destroy.

Exit status: 0 if every selected section passes (skipped counts as pass).
"""

from __future__ import print_function

import os
import sys
import traceback

try:
    import tkinter as tk
    from tkinter import TclError
except ImportError:  # Python 2
    import Tkinter as tk
    from Tkinter import TclError


SECTIONS = []


def section(label):
    def _d(fn):
        SECTIONS.append((label, fn))
        return fn
    return _d


# ---------------------------------------------------------------------------
# Sections
# ---------------------------------------------------------------------------


@section("import")
def s_import():
    import _tkinter
    print("  _tkinter    : {0}".format(_tkinter.__file__))
    print("  tkinter pkg : {0}".format(tk.__file__))
    print("  TclVersion  : {0}".format(tk.TclVersion))
    print("  TkVersion   : {0}".format(tk.TkVersion))


@section("tcl interpreter (no display needed)")
def s_tcl():
    interp = tk.Tcl()

    patch = interp.eval("info patchlevel")
    print("  patchlevel  : {0}".format(patch))

    lib = interp.eval("info library")
    print("  tcl_library : {0}".format(lib))
    assert lib, "info library returned empty string"
    # Sanity: the reported library dir should exist on disk.
    assert os.path.isdir(lib), "tcl_library points at non-existent dir: " + lib

    # Basic language features
    assert interp.eval("expr 7 * 6") == "42"
    assert interp.eval("string length standalone-python") == "17"
    assert interp.eval("list a b c") == "a b c"

    # Unicode round-trip
    try:
        result = interp.eval('string length "héllo"')
        print("  unicode len : {0}".format(result))
    except TclError as e:
        print("  unicode     : TclError -> {0}".format(e))

    print("  eval ok     : arithmetic, string, list, unicode")


@section("tk package discovery")
def s_tk_path():
    interp = tk.Tcl()
    try:
        interp.eval("package require Tk")
        print("  package Tk loaded (display was available)")
    except TclError as e:
        msg = str(e).splitlines()[0]
        # Typical errors:
        #   "no display name and no $DISPLAY environment variable"
        #   "couldn't connect to display"
        #   "can't find package Tk"  <-- THIS is the one we worry about:
        #                               means tk.tcl files are missing / unreachable
        if "can't find package Tk" in msg or "not found" in msg.lower():
            raise AssertionError(
                "Tk package files are not discoverable at runtime "
                "(relocation / TCLLIBPATH issue): " + msg
            )
        print("  Tk present but display unavailable: {0}".format(msg))


@section("gui (needs $DISPLAY)")
def s_gui():
    if not os.environ.get("DISPLAY"):
        print("  skipped: no $DISPLAY (headless)")
        return
    root = tk.Tk()
    try:
        root.title("standalone-python smoke")
        tk.Label(root, text="hello from tkinter").pack()
        tk.Button(root, text="OK").pack()
        entry = tk.Entry(root)
        entry.insert(0, "input")
        entry.pack()
        root.update_idletasks()
        w = root.winfo_reqwidth()
        h = root.winfo_reqheight()
        children = [type(c).__name__ for c in root.winfo_children()]
        print("  geometry    : {0}x{1}".format(w, h))
        print("  children    : {0}".format(children))
        assert w > 0 and h > 0
        assert "Label" in children and "Button" in children and "Entry" in children
    finally:
        root.destroy()


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def main():
    print("=== tkinter / tcl-tk smoke ===")
    print("  python      : {0}".format(sys.version.splitlines()[0]))
    print("  platform    : {0}".format(sys.platform))
    print("  DISPLAY     : {0!r}".format(os.environ.get("DISPLAY")))

    failed = []
    for label, fn in SECTIONS:
        print("\n" + label + ":")
        try:
            fn()
        except Exception:
            failed.append(label)
            traceback.print_exc()

    print("\n" + "=" * 50)
    total = len(SECTIONS)
    print("summary: {0}/{1} passed".format(total - len(failed), total))
    if failed:
        print("FAILED: " + ", ".join(failed))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
