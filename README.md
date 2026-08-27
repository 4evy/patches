<!-- markdownlint-disable-next-line MD033 MD041 -->
<div align="center">

# 4evy patches

Patch stacks for software I use, pinned to exact upstream revisions.

[![Check](https://github.com/4evy/patches/actions/workflows/check.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/check.yml)
[![Guix](https://github.com/4evy/patches/actions/workflows/guix.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/guix.yml)
[![Website](https://github.com/4evy/patches/actions/workflows/pages.yml/badge.svg)](https://github.com/4evy/patches/actions/workflows/pages.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Repo size](https://img.shields.io/github/repo-size/4evy/patches)](https://github.com/4evy/patches)

</div>

Each stack contains a manifest and an ordered Quilt queue:

```text
stacks/<id>/
|-- stack.json
`-- patches/
    |-- series
    `-- *.patch
```

## Use

```sh
brew tap 4evy/patches https://github.com/4evy/patches
brew patches list
brew patches show STACK
brew patches validate STACK
brew patches check STACK SOURCE_DIR
brew patches apply STACK SOURCE_DIR
```

`check` is read-only. `apply` changes the source only after the complete
queue passes a dry run.

The Nix flake also exposes the CLI and patched packages:

```sh
nix run .#brew-patches -- check jj /path/to/jj
nix build .#jj
```

## Develop

```sh
nix develop
just check
```

## License

My original tooling, documentation, tests, and fixtures are licensed
under MIT. Patch files can contain upstream work and retain their
original notices. See [PATCH-LICENSE.md](PATCH-LICENSE.md).

I don't accept pull requests. Fork this repository for your own version.
