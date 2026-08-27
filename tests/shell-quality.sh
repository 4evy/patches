#!/bin/sh
# shellcheck shell=sh
set -eu

root=$(CDPATH='' cd "$(dirname "$0")/.." && pwd -P)
mode=${1:---check}
readonly root mode

case "$mode" in
    --check | --format-check | --write) ;;
    *)
        printf 'usage: %s [--check|--format-check|--write]\n' "$0" >&2
        exit 2
        ;;
esac

shell_files() {
    git -C "$root" ls-files --cached --others --exclude-standard -- \
        '*.sh' '*.bash' '*.zsh' '.envrc' '.envrc.example' | LC_ALL=C sort
}

workflow_files() {
    git -C "$root" ls-files --cached --others --exclude-standard -- \
        '.github/workflows/*.yml' | LC_ALL=C sort
}

assert_shell_file_header() (
    file=$1
    case "$file" in
        *.bash | *.zsh)
            printf '%s must use the .sh suffix and POSIX syntax\n' "$file" >&2
            return 1
            ;;
        *.sh)
            expected='#!/bin/sh'
            actual=$(sed -n '1p' "$root/$file")
            if [ "$actual" != "$expected" ]; then
                printf '%s must start with %s\n' "$file" "$expected" >&2
                return 1
            fi
            directive=$(sed -n '2p' "$root/$file")
            ;;
        *)
            directive=$(sed -n '1p' "$root/$file")
            ;;
    esac

    if [ "$directive" != '# shellcheck shell=sh' ]; then
        printf '%s must declare # shellcheck shell=sh\n' "$file" >&2
        return 1
    fi
)

format_shell_file() {
    file=$1
    case "$mode" in
        --write)
            shfmt --write --posix --indent 4 --case-indent --simplify "$file"
            ;;
        *)
            shfmt --diff --posix --indent 4 --case-indent --simplify "$file"
            ;;
    esac
}

cd "$root"
check_shell_files() (
    failed=false
    while IFS= read -r file; do
        [ -n "$file" ] || continue
        assert_shell_file_header "$file" || failed=true
        sh -n "$file" || failed=true
        format_shell_file "$file" || failed=true
        if [ "$mode" != --format-check ]; then
            shellcheck -x --shell=sh "$file" || failed=true
        fi
    done
    [ "$failed" = false ]
)

shell_files | check_shell_files

# Shell entry points use the .sh suffix so the data-driven inventory above
# cannot silently miss an executable with an unusual name.
check_shell_suffixes() (
    while IFS= read -r file; do
        case "$file" in
            *.sh | *.bash | *.zsh) continue ;;
        esac
        if sed -n '1p' "$file" 2>/dev/null |
            grep -Eq '^#!.*[/[:space:]](ba|da|k|z)?sh([[:space:]]|$)'; then
            printf 'shell entry point must use a recognized shell suffix: %s\n' \
                "$file" >&2
            return 1
        fi
    done
)

git ls-files --cached --others --exclude-standard | check_shell_suffixes

check_workflow_shells() (
    while IFS= read -r workflow; do
        [ -n "$workflow" ] || continue
        grep -q '^[[:space:]]*run:' "$workflow" || continue
        if ! grep -q '^defaults:$' "$workflow" ||
            ! grep -q '^[[:space:]]*shell: sh$' "$workflow"; then
            printf '%s must set defaults.run.shell to sh\n' "$workflow" >&2
            return 1
        fi
        if grep -q '^[[:space:]]*shell: bash$' "$workflow"; then
            printf '%s contains an explicit Bash run block\n' "$workflow" >&2
            return 1
        fi
    done
)

workflow_files | check_workflow_shells

printf 'POSIX shell quality checks passed for %s files.\n' \
    "$(shell_files | wc -l | tr -d ' ')"
