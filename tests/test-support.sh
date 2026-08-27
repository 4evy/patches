#!/bin/sh
# shellcheck shell=sh

TEST_TEMP_MARKER=.4evy-test-directory
TEST_TEMP_MAX_ATTEMPTS=10
readonly TEST_TEMP_MARKER TEST_TEMP_MAX_ATTEMPTS

project_root() (
    CDPATH=
    export CDPATH
    cd "$(dirname "$1")/.." && pwd -P
)

make_temp_dir() (
    prefix=$1
    base=${TMPDIR:-/tmp}
    attempt=0

    while :; do
        attempt=$((attempt + 1))
        candidate="$base/$prefix.$$"
        [ "$attempt" -eq 1 ] || candidate="$base/$prefix.$$.$attempt"
        if (umask 077 && mkdir "$candidate") 2>/dev/null; then
            : >"$candidate/$TEST_TEMP_MARKER"
            printf '%s\n' "$candidate"
            return 0
        fi
        if [ "$attempt" -ge "$TEST_TEMP_MAX_ATTEMPTS" ]; then
            printf 'could not create a temporary directory\n' >&2
            return 1
        fi
    done
)

remove_temp_dir() (
    directory=$1
    [ -e "$directory" ] || return 0
    if [ ! -f "$directory/$TEST_TEMP_MARKER" ]; then
        printf 'refusing to remove unmarked temporary directory: %s\n' \
            "$directory" >&2
        return 1
    fi
    rm -rf -- "$directory"
)

install_cleanup_traps() {
    trap cleanup 0
    trap 'exit 129' HUP
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

create_demo_stack() (
    support_root=$1
    support_tmp=$2

    mkdir -p "$support_tmp/stacks/demo/patches"
    cp "$support_root/tests/fixtures/multi-file/patches/"*.patch \
        "$support_tmp/stacks/demo/patches/"
    cp "$support_root/tests/fixtures/multi-file/patches/series" \
        "$support_tmp/stacks/demo/patches/series"
    cp "$support_root/tests/fixtures/multi-file/stack.json" \
        "$support_tmp/stacks/demo/stack.json"
)
