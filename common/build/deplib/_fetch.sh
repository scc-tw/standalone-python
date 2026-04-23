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
#   * Per-URL: up to FETCH_PER_URL_TRIES attempts with linear backoff
#     between retries (0s, base, 2*base, ...).
#   * A 4xx response from a mirror short-circuits to the next mirror
#     (no point retrying "not found").
#   * First non-empty successful download wins; function returns 0.
#   * When all mirrors are exhausted, removes the partial output and
#     returns 1 — callers running `set -e` will abort with a clear
#     fetch_mirrored: ... message already on stderr.
#
# All log lines go to stderr so callers can capture stdout cleanly.
#
# Knobs (override via env before calling):
#     FETCH_PER_URL_TRIES    default 3
#     FETCH_CONNECT_TIMEOUT  default 10   seconds
#     FETCH_MAX_TIME         default 180  seconds per attempt
#     FETCH_BACKOFF_BASE     default 3    seconds; backoff = (n-1) * base
#
# POSIX-sh compatible (no bashisms); tested against dash and busybox-ash.

: "${FETCH_PER_URL_TRIES:=3}"
: "${FETCH_CONNECT_TIMEOUT:=10}"
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

            _http=$(curl -sS -L -f \
                         --connect-timeout "$FETCH_CONNECT_TIMEOUT" \
                         --max-time "$FETCH_MAX_TIME" \
                         -o "$_out" \
                         -w '%{http_code}' \
                         "$_url" 2>/dev/null)
            _rc=$?

            if [ "$_rc" -eq 0 ] && [ -s "$_out" ]; then
                printf '    ok: %d bytes\n' "$(wc -c < "$_out")" >&2
                return 0
            fi

            rm -f "$_out"

            # 4xx → wrong URL for this mirror; skip remaining retries here.
            case "$_http" in
                4??)
                    printf '    HTTP %s — skipping mirror\n' "$_http" >&2
                    break
                    ;;
            esac

            printf '    attempt %d failed (curl=%d http=%s)\n' \
                   "$_attempt" "$_rc" "${_http:-?}" >&2
            _attempt=$(( _attempt + 1 ))
        done
    done

    echo "fetch_mirrored: all mirrors exhausted for $_out" >&2
    return 1
}
