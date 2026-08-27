#!/bin/sh
# shellcheck shell=sh
# shellcheck source=tests/test-support.sh
set -eu

. "$(dirname "$0")/test-support.sh"
root=$(project_root "$0")
tmp=$(make_temp_dir patches-website)
server_pid=
host=127.0.0.1
port=4328
max_start_attempts=20
base_url="http://$host:$port/patches"
readonly root tmp host port max_start_attempts base_url

cleanup() {
    if [ -n "$server_pid" ]; then
        kill "$server_pid" 2>/dev/null || :
        wait "$server_pid" 2>/dev/null || :
    fi
    remove_temp_dir "$tmp"
}

fetch() (
    route=$1
    destination=$2
    curl -fsS "$base_url$route" >"$destination"
)

assert_http_status() (
    expected=$1
    route=$2
    actual=$(curl -sS -o /dev/null -w '%{http_code}' "$base_url$route")
    if [ "$actual" != "$expected" ]; then
        printf 'expected HTTP %s for %s, received %s\n' \
            "$expected" "$route" "$actual" >&2
        return 1
    fi
)

install_cleanup_traps

create_demo_stack "$root" "$tmp"

(cd "$root" && PATCHES_STACKS="$tmp/stacks" \
    PATCHES_DIST="$tmp/dist" npm run build)

mkdir "$tmp/www"
ln -s "$tmp/dist" "$tmp/www/patches"
python3 -m http.server "$port" --bind "$host" \
    --directory "$tmp/www" >"$tmp/server.log" 2>&1 &
server_pid=$!

attempt=0
until fetch /healthz "$tmp/health.json" 2>/dev/null; do
    attempt=$((attempt + 1))
    if test "$attempt" -ge "$max_start_attempts" ||
        ! kill -0 "$server_pid" 2>/dev/null; then
        sed -n '1,200p' "$tmp/server.log" >&2
        exit 1
    fi
    sleep 1
done

while IFS=' ' read -r route output; do
    fetch "$route" "$tmp/$output"
done <<'EOF'
/ home.html
/stacks/demo/ stack.html
/stacks/demo/patches/mark-main.patch/ patch.html
/catalog.json catalog.json
/stacks.json stacks.json
/stacks/demo.json demo.json
EOF

grep -q 'Use dark color theme' "$tmp/home.html"
grep -q 'href="/patches/_astro/' "$tmp/home.html"
grep -q 'href="/patches/stacks/demo/"' "$tmp/home.html"
grep -q 'aria-describedby="patch-scroll-hint"' "$tmp/patch.html"
grep -q 'id="patch-scroll-hint"' "$tmp/patch.html"
if grep -q '<abbr' "$tmp/stack.html"; then
    printf '%s\n' 'Stack metadata must not misuse the abbreviation element' >&2
    exit 1
fi
node -e '
  const fs = require("node:fs");
  const html = fs.readFileSync(process.argv[1], "utf8");
  const primaryNav = html.match(/<nav class="site-links"[\s\S]*?<\/nav>/)?.[0];
  if (!primaryNav || primaryNav.includes("theme-toggle")) process.exit(1);
' "$tmp/home.html"

node -e '
  const fs = require("node:fs");
  const read = (name) => JSON.parse(fs.readFileSync(name));
  const [health, catalog, stacks, demo] = process.argv.slice(1).map(read);
  if (health.status !== "ok") process.exit(1);
  if (catalog.stacks.length !== 1 || catalog.stacks[0].id !== "demo") process.exit(1);
  if (JSON.stringify(stacks) !== JSON.stringify(["demo"])) process.exit(1);
  if (demo.id !== "demo" || demo.patches[0] !== "mark-main.patch") process.exit(1);
' "$tmp/health.json" "$tmp/catalog.json" "$tmp/stacks.json" "$tmp/demo.json"

for route in /stacks/missing/ /stacks/demo/patches/missing.patch/; do
    assert_http_status 404 "$route"
done

# Catalog symlinks must not make files outside the configured root public.
cp -R "$tmp/stacks/demo" "$tmp/outside-stack"
node -e '
  const fs = require("node:fs");
  const file = process.argv[1];
  const manifest = JSON.parse(fs.readFileSync(file));
  manifest.id = "escaped-stack";
  fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + "\n");
' "$tmp/outside-stack/stack.json"
ln -s "$tmp/outside-stack" "$tmp/stacks/escaped-stack"
assert_http_status 404 /stacks/escaped-stack/

cp "$tmp/stacks/demo/patches/mark-main.patch" "$tmp/outside.patch"
ln -s "$tmp/outside.patch" "$tmp/stacks/demo/patches/escaped.patch"
printf '%s\n' escaped.patch >>"$tmp/stacks/demo/patches/series"
assert_http_status 404 /stacks/demo/patches/escaped.patch/

cp -R "$tmp/stacks/demo" "$tmp/escaped-patches-stack"
mv "$tmp/escaped-patches-stack/patches" "$tmp/outside-patches"
ln -s "$tmp/outside-patches" "$tmp/escaped-patches-stack/patches"
mv "$tmp/escaped-patches-stack" "$tmp/stacks/escaped-patches"
node -e '
  const fs = require("node:fs");
  const file = process.argv[1];
  const manifest = JSON.parse(fs.readFileSync(file));
  manifest.id = "escaped-patches";
  fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + "\n");
' "$tmp/stacks/escaped-patches/stack.json"
assert_http_status 404 /stacks/escaped-patches/

cp -R "$tmp/stacks/demo" "$tmp/stacks/escaped-manifest"
cp "$tmp/stacks/escaped-manifest/stack.json" "$tmp/outside-manifest.json"
rm "$tmp/stacks/escaped-manifest/stack.json"
ln -s "$tmp/outside-manifest.json" \
    "$tmp/stacks/escaped-manifest/stack.json"
assert_http_status 404 /stacks/escaped-manifest/

# Changes made after the build must not alter the generated catalog.
cp -R "$tmp/stacks/demo" "$tmp/stacks/runtime"
node -e '
  const fs = require("node:fs");
  const file = process.argv[1];
  const manifest = JSON.parse(fs.readFileSync(file));
  manifest.id = "runtime";
  fs.writeFileSync(file, JSON.stringify(manifest, null, 2) + "\n");
' "$tmp/stacks/runtime/stack.json"
fetch /stacks.json "$tmp/runtime-stacks.json"
node -e '
  const fs = require("node:fs");
  const stacks = JSON.parse(fs.readFileSync(process.argv[1]));
  if (JSON.stringify(stacks) !== JSON.stringify(["demo"])) process.exit(1);
' "$tmp/runtime-stacks.json"

cp "$tmp/stacks/demo/patches/mark-main.patch" \
    "$tmp/stacks/demo/patches/runtime.patch"
printf '%s\n' 'runtime.patch' >>"$tmp/stacks/demo/patches/series"
fetch /stacks/demo.json "$tmp/runtime-series.json"
node -e '
  const fs = require("node:fs");
  const stack = JSON.parse(fs.readFileSync(process.argv[1]));
  if (JSON.stringify(stack.patches) !== JSON.stringify(["mark-main.patch", "extend-api.patch", "use-api.patch"])) process.exit(1);
' "$tmp/runtime-series.json"

npm exec --workspace 4evy-patches-site -- html-validate \
    "$tmp/home.html" "$tmp/stack.html" "$tmp/patch.html"

printf '%s\n' 'Static website workflow ok'
