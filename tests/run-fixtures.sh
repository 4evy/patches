#!/bin/sh
# shellcheck shell=sh
# shellcheck source=tests/test-support.sh
set -eu

. "$(dirname "$0")/test-support.sh"
root=$(project_root "$0")
fixtures="$root/tests/fixtures"
tmp=$(make_temp_dir 4evy-fixtures)
readonly root fixtures tmp

cleanup() {
    remove_temp_dir "$tmp"
}

install_cleanup_traps

run_if_available() (
    tool=$1
    shift
    if command -v "$tool" >/dev/null 2>&1; then
        "$@"
    fi
)

run_go() (
    work=$1
    (cd "$work" && GO111MODULE=off go run main.go >/dev/null)
)

for series in "$fixtures"/*/patches/series; do
    [ -f "$series" ] || continue
    fixture=${series%/patches/series}
    name="$(basename "$fixture")"
    work="$tmp/$name"
    cp -R "$fixture/upstream" "$work"
    patch_count=$(awk 'NF && $1 !~ /^#/ { count++ } END { print count + 0 }' \
        "$series")
    if [ "$patch_count" -lt 2 ]; then
        printf 'fixture %s has fewer than two patches\n' "$name" >&2
        exit 1
    fi

    while IFS= read -r patch_name; do
        [ -n "$patch_name" ] || continue
        patch="$fixture/patches/$patch_name"
        if ! grep '^diff --git ' "$patch" >/dev/null || ! grep '^index ' "$patch" >/dev/null; then
            printf 'fixture %s patch %s is not a Git patch\n' "$name" "$patch_name" >&2
            exit 1
        fi
        git -C "$work" apply --check "$patch"
        git -C "$work" apply "$patch"
    done <"$series"

    case "$name" in
        c)
            run_if_available cc cc -fsyntax-only "$work/main.c"
            ;;
        cpp)
            run_if_available c++ c++ -fsyntax-only "$work/main.cpp"
            ;;
        zig)
            run_if_available zig zig build-exe -fno-emit-bin "$work/main.zig"
            ;;
        java)
            if command -v javac >/dev/null 2>&1; then
                mkdir "$work/classes"
                javac -d "$work/classes" "$work/Main.java"
            fi
            ;;
        kotlin)
            run_if_available kotlinc kotlinc "$work/Main.kt" -d "$work/main.jar"
            ;;
        csharp)
            run_if_available csc csc /nologo /target:exe /out:"$work/main.exe" "$work/Program.cs"
            ;;
        go)
            run_if_available go run_go "$work"
            ;;
        rust)
            run_if_available rustc rustc --emit=metadata -o "$work/main.rmeta" "$work/main.rs"
            ;;
        typescript)
            if command -v tsc >/dev/null 2>&1; then
                mkdir "$work/types"
                (cd "$work" && tsc --noEmit --target ES2022 \
                    --typeRoots types main.ts)
            fi
            ;;
        python)
            run_if_available python3 python3 -m py_compile "$work/main.py"
            ;;
        shell)
            sh -n "$work/main.sh"
            shfmt --diff --posix --indent 4 --case-indent --simplify \
                "$work/main.sh"
            run_if_available shellcheck shellcheck -x --shell=sh "$work/main.sh"
            ;;
        swift)
            run_if_available swiftc swiftc -parse "$work/main.swift"
            ;;
        lua)
            run_if_available lua lua -e "assert(loadfile('$work/main.lua'))"
            ;;
        multi-file)
            run_if_available cc cc -fsyntax-only "$work/main.c" "$work/message.c" "$work/extra.c"
            ;;
        *)
            printf 'fixture %s has no validation command\n' "$name" >&2
            exit 1
            ;;
    esac

    printf 'fixture %-12s ok\n' "$name"
done
