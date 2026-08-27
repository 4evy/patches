# Stacks

Create one directory for each upstream project.

A minimal stack looks like this:

```text
stacks/project/
|-- stack.json
`-- patches/
    `-- series
```

Put one patch filename on each line of `series`. Quilt options and
comments can follow each filename, as described in the Quilt
specification.

To expose a stack as a Nix package, add `package.nix` beside
`stack.json`. The central loader discovers it automatically and supplies
the parsed `manifest` plus the ordered `patches` list to `callPackage`.
