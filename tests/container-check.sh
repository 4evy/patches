#!/bin/sh
# shellcheck shell=sh
# shellcheck source=tests/test-support.sh
set -eu

script_dir=$(dirname "$0")
. "$script_dir/test-support.sh"
root=$(project_root "$0")
project="patches_container_check_$$"
image=${CONTAINER_IMAGE:-localhost/4evy/patches:check-$$}
readonly root project image
built=false

select_container_engine() (
    if [ -n "${CONTAINER_ENGINE:-}" ]; then
        candidates=$CONTAINER_ENGINE
    else
        candidates='docker podman'
    fi

    for candidate in $candidates; do
        if command -v "$candidate" >/dev/null 2>&1 &&
            "$candidate" info >/dev/null 2>&1; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf 'No working Docker or Podman engine is available.\n' >&2
    return 1
)

engine=$(select_container_engine)
compose_provider=
if [ "$engine" = podman ] && command -v podman-compose >/dev/null 2>&1; then
    compose_provider=$(command -v podman-compose)
fi
readonly engine compose_provider

cd "$root"

compose() {
    if [ -n "$compose_provider" ]; then
        PODMAN_COMPOSE_PROVIDER=$compose_provider \
            PATCHES_IMAGE=$image COMPOSE_PROJECT_NAME=$project \
            "$engine" compose "$@"
    else
        PATCHES_IMAGE=$image COMPOSE_PROJECT_NAME=$project \
            "$engine" compose "$@"
    fi
}

cleanup() {
    compose down --remove-orphans >/dev/null 2>&1 || :
    if [ "$built" = true ]; then
        "$engine" image rm --force "$image" >/dev/null 2>&1 || :
    fi
}

assert_equal() (
    description=$1
    expected=$2
    actual=$3
    if [ "$actual" != "$expected" ]; then
        printf '%s mismatch\nexpected:\n%s\nactual:\n%s\n' \
            "$description" "$expected" "$actual" >&2
        return 1
    fi
)

image_config() {
    "$engine" image inspect --format "$1" "$image"
}

install_cleanup_traps

compose config >/dev/null

if [ "${CONTAINER_SKIP_BUILD:-false}" != true ]; then
    compose build
    built=true

    first_id=$(image_config '{{.Id}}')
    compose build
    second_id=$(image_config '{{.Id}}')
    assert_equal 'cached image ID' "$first_id" "$second_id"
fi

assert_equal 'image user' 10001:10001 "$(image_config '{{.Config.User}}')"
for label in version revision; do
    label_value=$(image_config \
        "{{index .Config.Labels \"org.opencontainers.image.$label\"}}")
    if [ -z "$label_value" ]; then
        printf 'image label %s is empty\n' "$label" >&2
        exit 1
    fi
done

native_list=$(ruby cmd/brew-patches.rb list)
container_list=$("$engine" run --rm --network none "$image" list)
assert_equal 'container list output' "$native_list" "$container_list"

native_validate=$(ruby cmd/brew-patches.rb validate)
container_validate=$("$engine" run --rm --network none --read-only \
    --cap-drop ALL --security-opt no-new-privileges "$image" validate)
assert_equal 'container validation output' "$native_validate" "$container_validate"

first_stack=$(printf '%s\n' "$native_list" | sed -n '1p')
native_show=$(ruby cmd/brew-patches.rb show "$first_stack" --json)
container_show=$("$engine" run --rm --network none \
    "$image" show "$first_stack" --json)
assert_equal 'container show output' "$native_show" "$container_show"

# podman-compose prints the temporary container ID before command output.
compose_list=$(compose run --rm -T patches | sed '1{/^[[:xdigit:]]\{64\}$/d;}')
assert_equal 'Compose list output' "$native_list" "$compose_list"

# The checks intentionally expand inside the container rather than in this shell.
# shellcheck disable=SC2016
compose run --rm -T --entrypoint sh patches -ec '
    test "$(id -u)" = 10001
    set -- $(grep ^CapEff: /proc/self/status)
    test "$2" = 0000000000000000
    set -- $(grep ^NoNewPrivs: /proc/self/status)
    test "$2" = 1
    test "$(ls /sys/class/net)" = lo
    touch /tmp/patches-container-check
' >/dev/null

compose up --abort-on-container-exit --exit-code-from patches >/dev/null

printf 'Container and Compose checks passed with %s.\n' "$engine"
