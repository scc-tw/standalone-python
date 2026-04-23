#!/bin/sh
#
# Resilient multi-mirror tarball fetcher, sourced by deplib build scripts.
#
# Usage:
#     . ./_fetch.sh
#     fetch_mirrored <output_file> <url1> [<url2> [<url3> ...]]
#
# Behaviour:
#   * Tries each URL in order.
#   * Per-URL: up to FETCH_PER_URL_TRIES attempts with linear backoff.
#   * First non-empty successful download wins; returns 0.
#   * When all mirrors are exhausted, removes the partial output and
#     returns 1 — callers running `set -e` will abort with a clear
#     fetch_mirrored: ... message already on stderr.
#
# All log lines go to stderr so callers can capture stdout cleanly.
#
# Uses wget — it's in every deplib stage (apk'd in Alpine base_builder)
# and avoids pulling curl in as another dependency. wget doesn't expose
# HTTP status cleanly, so we conservatively retry on any non-zero exit
# and fall through to the next mirror when our per-URL budget is spent.
# In practice a 404 just burns FETCH_PER_URL_TRIES attempts before
# rolling to the next mirror — fine at our build frequency.
#
# Knobs (override via env before calling):
#     FETCH_PER_URL_TRIES    default 3
#     FETCH_MAX_TIME         default 180  seconds per attempt
#     FETCH_BACKOFF_BASE     default 3    seconds; backoff = (n-1) * base
#
# POSIX-sh compatible (no bashisms); tested against dash and busybox-ash.

: "${FETCH_PER_URL_TRIES:=3}"
: "${FETCH_MAX_TIME:=180}"
: "${FETCH_BACKOFF_BASE:=3}"

fetch_mirrored() {
    _out=$1
    shift
    if [ $# -eq 0 ]; then
        echo "fetch_mirrored: no URLs given for $_out" >&2
        return 2
    fi

    rm -f "$_out"

    for _url in "$@"; do
        printf '>>> fetch %s\n' "$_url" >&2
        _attempt=1
        while [ "$_attempt" -le "$FETCH_PER_URL_TRIES" ]; do
            if [ "$_attempt" -gt 1 ]; then
                _wait=$(( (_attempt - 1) * FETCH_BACKOFF_BASE ))
                printf '    backoff %ds before retry %d\n' "$_wait" "$_attempt" >&2
                sleep "$_wait"
            fi

            # -nv: one-line per request (no progress bar — CI-friendly).
            # --tries=1: we own the retry logic out here (for backoff).
            # --timeout: combined connect + read timeout.
            if wget -nv --tries=1 --timeout="$FETCH_MAX_TIME" -O "$_out" "$_url"; then
                if [ -s "$_out" ]; then
                    printf '    ok: %d bytes\n' "$(wc -c < "$_out")" >&2
                    return 0
                fi
            fi
            _rc=$?
            rm -f "$_out"
            printf '    attempt %d failed (wget=%d)\n' "$_attempt" "$_rc" >&2
            _attempt=$(( _attempt + 1 ))
        done
    done

    echo "fetch_mirrored: all mirrors exhausted for $_out" >&2
    return 1
}
