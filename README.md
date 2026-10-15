# 4evy patches

Patch stacks for software I use, pinned to exact upstream revisions, with
Nix packages that apply them.

Each stack contains a manifest, a package definition, and an ordered Quilt
queue:

```text
stacks/<id>/
|-- stack.json
|-- package.nix
`-- patches/
    |-- series
    `-- *.patch
```

See [stacks/README.md](stacks/README.md) for the stack format.

## Use

```sh
nix build .#jj
nix build .#kanata
nix build .#ghostty
```

Jujutsu and Kanata are exposed on Apple Silicon macOS, aarch64 Linux, and
x86_64 Linux. Ghostty is exposed on Linux. The flake also exports each
stack's pinned source metadata as `stackSources`.

## Format and evaluate

```sh
nix fmt
nix flake check --no-build --no-write-lock-file
```

## License

My original package definitions and documentation are licensed under MIT.
Patch files can contain upstream work and retain their original notices.
See [PATCH-LICENSE.md](PATCH-LICENSE.md).

I don't accept pull requests. Fork this repository for your own version.
