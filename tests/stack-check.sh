#!/bin/sh
# shellcheck shell=sh
# shellcheck source=tests/test-support.sh
set -eu

. "$(dirname "$0")/test-support.sh"
root=$(project_root "$0")
tmp=$(make_temp_dir 4evy-stacks)
readonly root tmp

cleanup() {
    remove_temp_dir "$tmp"
}

manifest_value() (
    manifest=$1
    key=$2
    ruby --disable-gems -rjson -e \
        'puts JSON.parse(File.read(ARGV[0])).dig(*ARGV[1].split("."))' \
        "$manifest" "$key"
)

install_cleanup_traps

if [ "$#" -eq 0 ]; then
    # Stack IDs cannot contain whitespace; splitting turns the list into args.
    # shellcheck disable=SC2046
    set -- $(ruby --disable-gems "$root/cmd/brew-patches.rb" list)
fi

for stack in "$@"; do
    ruby --disable-gems "$root/cmd/brew-patches.rb" \
        validate "$stack" >/dev/null
    manifest="$root/stacks/$stack/stack.json"
    source="$tmp/$stack"
    canonical=$(manifest_value "$manifest" source.canonical)
    revision=$(manifest_value "$manifest" source.revision)

    git init --quiet "$source"
    git -C "$source" remote add origin "$canonical"
    git -C "$source" fetch --quiet --depth=1 origin "$revision"
    git -C "$source" checkout --quiet --detach FETCH_HEAD

    actual_revision=$(git -C "$source" rev-parse HEAD)
    if [ "$actual_revision" != "$revision" ]; then
        printf 'expected %s at %s, fetched %s\n' \
            "$stack" "$revision" "$actual_revision" >&2
        exit 1
    fi

    ruby --disable-gems "$root/cmd/brew-patches.rb" check "$stack" "$source"
done

printf 'Checked %s real patch stack%s.\n' "$#" \
    "$(test "$#" -eq 1 || printf s)"
