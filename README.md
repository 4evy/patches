<!-- markdownlint-disable-next-line MD033 MD041 -->
<div align="center">

# 4evy patches

Git patch stacks for software I use

[![Check](https://github.com/4evy/patches/actions/workflows/check.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/check.yml)
[![Security](https://github.com/4evy/patches/actions/workflows/security.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/security.yml)
[![Guix](https://github.com/4evy/patches/actions/workflows/guix.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/guix.yml)
[![Website](https://github.com/4evy/patches/actions/workflows/pages.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/pages.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/4evy/patches)](https://github.com/4evy/patches/commits/master)
[![Repo size](https://img.shields.io/github/repo-size/4evy/patches)](https://github.com/4evy/patches)

</div>

I keep each stack's patches, order, and exact upstream source together
so I can reproduce a local change without maintaining a fork

## Use a stack

Each stack has a manifest and an ordered Quilt queue

```text
stacks/<id>/
|-- stack.json
`-- patches/
    |-- series
    `-- *.patch
```

I use `patches/series` for patch order and `stack.json` for upstream
identity and the immutable source revision. I validate the manifest
against [`schema/stack-v1.schema.json`](schema/stack-v1.schema.json)

```sh
brew tap 4evy/patches https://github.com/4evy/patches
brew patches list
brew patches show STACK
brew patches validate STACK
brew patches check STACK SOURCE_DIR
brew patches apply STACK SOURCE_DIR
```

`check` is read-only. `apply` changes the source only after the complete
queue passes its dry run

## Develop

I use Nix for the CLI and repository tooling

```sh
nix develop
just check
```

The flake also exposes a package for every real patch stack. For
example, `nix build .#jj` builds the pinned Jujutsu source with its full
queue applied; on Linux, `nix build .#ghostty` does the same for
Ghostty. These release derivations compile without running development
tests.

The flake exports `nixosModules.default`, `homeManagerModules.default`,
and `darwinModules.default`. Import the matching module and set
`programs._4evy.enable = true`. Override `programs._4evy.packages` when
you only need part of the default development tool set.

The `Patched packages` workflow performs an independent native Linux
release build (without Nix and without tests) for every stack. Each job
uploads the compiled executable, a complete `.tar.gz` and `.zip`, and
installable `.deb` and `.rpm` packages. Tagged builds also attach all of
these files to the matching GitHub release.

I also support classic Nix and Guix

```sh
guix pull -C guix/four-evy/channels.scm
guix shell -L packaging/guix -m guix/four-evy/manifest.scm
```

The channel file follows Guix's canonical project URL (which redirects
to Codeberg) and Nonguix's declared GitLab primary. The manifest
installs the explicit Guix-supported subset of the development tools;
`guix/four-evy/tooling.scm` keeps the remaining Nix-shell tools visible
in an unsupported list.

The packaged CLI is functional in both environments and carries the
complete patch catalog:

```sh
nix run .#brew-patches -- check jj /path/to/jj
nix run .#brew-patches -- apply jj /path/to/jj

guix shell -L packaging/guix -m guix/four-evy/manifest.scm -- \
  brew-patches check jj /path/to/jj
guix shell -L packaging/guix -m guix/four-evy/manifest.scm -- \
  brew-patches apply jj /path/to/jj
```

`check` always works on a temporary copy; `apply` first checks the full
queue on a temporary copy and only then changes the requested checkout.
The Nix flake also exposes patched `ghostty`, `jj`, and `kanata` build
outputs as `.#ghostty`, `.#jj`, and `.#kanata` where the upstream
package supports the current platform.

## Run the catalog

I can run the read-only CLI as a container

```sh
git clone https://github.com/4evy/patches.git
cd patches
docker compose run --rm patches
```

The same definition works with rootless Podman:

```sh
podman compose run --rm patches
CONTAINER_ENGINE=podman just container-check
```

The catalog is one Astro application running on Node.js 26.7.0. It reads
`stacks/`, each manifest, and each Quilt series when a request arrives,
so adding or editing a stack does not require regenerating source files
or rebuilding the site. The same server exposes `GET /catalog.json`,
`GET /stacks.json`, `GET /stacks/{id}.json`, and `GET /healthz`.

```sh
npm ci
npm run build
npm start
```

Set `PATCHES_STACKS` when the stack directory is not `./stacks` or
`../stacks`. The server also accepts the standard `HOST` and `PORT`
environment variables.

## Notes

I run `just check` before relying on a change. CI checks Linux and
macOS, and Renovate is my only dependency updater

My tag and manually approved workflows produce an SBOM, keyless Cosign
signatures, and build attestations

I license my original tooling, docs, tests, and fixtures under MIT.
Patch files can contain upstream work, so I keep their original notices.
See [PATCH-LICENSE.md](PATCH-LICENSE.md)

I do not accept pull requests. Fork this repository for your own version
