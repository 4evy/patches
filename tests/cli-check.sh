#!/bin/sh
# shellcheck shell=sh
# shellcheck source=tests/test-support.sh
set -eu

. "$(dirname "$0")/test-support.sh"
root=$(project_root "$0")
tmp=$(make_temp_dir patches-cli)
readonly root tmp

cleanup() {
    remove_temp_dir "$tmp"
}

run_cli() {
    PATCHES_STACKS="$tmp/stacks" ruby "$root/cmd/brew-patches.rb" "$@"
}

assert_cli_failure() {
    expected=$1
    shift
    output="$tmp/cli-failure.log"
    if run_cli "$@" >"$output" 2>&1; then
        printf 'command unexpectedly succeeded: %s\n' "$*" >&2
        exit 1
    fi
    grep -F "$expected" "$output" >/dev/null
}

copy_stack_as() {
    id=$1
    cp -R "$tmp/stacks/demo" "$tmp/stacks/$id"
    ruby --disable-gems -rjson -e '
      path = ARGV[0]
      manifest = JSON.parse(File.read(path))
      manifest["id"] = ARGV[1]
      File.write(path, JSON.pretty_generate(manifest) + "\n")
    ' "$tmp/stacks/$id/stack.json" "$id"
}

install_cleanup_traps

ruby "$root/cmd/brew-patches.rb" validate
create_demo_stack "$root" "$tmp"
cp -R "$root/tests/fixtures/multi-file/upstream" "$tmp/source"
cp -R "$tmp/source" "$tmp/source-before-check"

run_cli validate demo
run_cli check demo "$tmp/source"
diff -ru "$tmp/source-before-check" "$tmp/source"

copy_stack_as broken-queue
ruby --disable-gems -e '
  path = ARGV[0]
  series = File.readlines(path)
  File.write(path, [series[2], series[1], series[0]].join)
' "$tmp/stacks/broken-queue/patches/series"
assert_cli_failure 'git apply failed' apply broken-queue "$tmp/source"
diff -ru "$tmp/source-before-check" "$tmp/source"

for invalid in extra-property invalid-endpoint invalid-checkout invalid-url \
    invalid-result; do
    copy_stack_as "$invalid"
    ruby --disable-gems -rjson -e '
      path, invalid = ARGV
      manifest = JSON.parse(File.read(path))
      case invalid
      when "extra-property"
        manifest["unexpected"] = true
      when "invalid-endpoint"
        manifest["source"]["endpoints"] = [7]
      when "invalid-checkout"
        manifest["source"]["checkout"] = { "submodules" => true }
      when "invalid-url"
        manifest["source"]["canonical"] = "https: not a URL"
      when "invalid-result"
        manifest["result"] = { "tree" => { "algorithm" => "md5" } }
      end
      File.write(path, JSON.pretty_generate(manifest) + "\n")
    ' "$tmp/stacks/$invalid/stack.json" "$invalid"
done

assert_cli_failure 'manifest contains unknown property unexpected' \
    validate extra-property
assert_cli_failure 'source.endpoints[0] must be an object' \
    validate invalid-endpoint
assert_cli_failure 'source.checkout.submodules must be false or recursive' \
    validate invalid-checkout
assert_cli_failure 'source.canonical must be a URI' validate invalid-url
assert_cli_failure 'result.tree.algorithm is invalid' validate invalid-result
assert_cli_failure 'result.tree.oid must be a full object ID' \
    validate invalid-result

copy_stack_as duplicate-series
first_patch=$(sed -n '1p' "$tmp/stacks/duplicate-series/patches/series")
printf '%s\n' "$first_patch" >> \
    "$tmp/stacks/duplicate-series/patches/series"
assert_cli_failure 'series contains duplicate patch' validate duplicate-series

copy_stack_as escaped-patch
ln -s "$tmp/stacks/demo/patches/mark-main.patch" \
    "$tmp/stacks/escaped-patch/patches/escaped.patch"
printf '%s\n' escaped.patch > \
    "$tmp/stacks/escaped-patch/patches/series"
assert_cli_failure 'does not name a patch below patches/' \
    validate escaped-patch

ln -s "$tmp/stacks/demo" "$tmp/stacks/escaped-stack"
if run_cli list | grep -Fx escaped-stack >/dev/null; then
    printf '%s\n' 'list exposed a stack symlink' >&2
    exit 1
fi
assert_cli_failure 'Unknown stack: escaped-stack' validate escaped-stack

copy_stack_as escaped-patches
mv "$tmp/stacks/escaped-patches/patches" "$tmp/outside-patches"
ln -s "$tmp/outside-patches" "$tmp/stacks/escaped-patches/patches"
assert_cli_failure 'patches/ escapes the stack directory' \
    validate escaped-patches
assert_cli_failure 'patches/ escapes the stack directory' \
    show escaped-patches

copy_stack_as escaped-manifest
mv "$tmp/stacks/escaped-manifest/stack.json" "$tmp/outside-manifest.json"
ln -s "$tmp/outside-manifest.json" \
    "$tmp/stacks/escaped-manifest/stack.json"
assert_cli_failure 'Manifest escapes the stack directory' \
    validate escaped-manifest

run_cli apply demo "$tmp/source"
grep -q 'extra_value' "$tmp/source/main.c"
run_cli show demo --json | ruby -rjson \
    -e 'abort unless JSON.parse(STDIN.read)["patches"].length == 3'
printf '%s\n' 'CLI workflow ok'
