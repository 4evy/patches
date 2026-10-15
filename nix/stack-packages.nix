{ callPackage, lib }:

let
  stackRoot = ../stacks;

  patchesFor =
    stackPath:
    let
      patchRoot = lib.path.append stackPath "patches";
    in
    lib.trivial.pipe (builtins.readFile (lib.path.append patchRoot "series")) [
      (lib.strings.splitString "\n")
      (lib.lists.concatMap (
        line:
        let
          match = builtins.match "[[:space:]]*([^#[:space:]]+).*" line;
        in
        lib.lists.optional (match != null) (lib.path.append patchRoot (lib.lists.head match))
      ))
    ];

  packages = lib.attrsets.concatMapAttrs (
    name: type:
    let
      stackPath = lib.path.append stackRoot name;
      packagePath = lib.path.append stackPath "package.nix";
    in
    lib.attrsets.optionalAttrs (type == "directory" && lib.filesystem.pathIsRegularFile packagePath) {
      ${name} = callPackage packagePath {
        manifest = lib.trivial.importJSON (lib.path.append stackPath "stack.json");
        patches = patchesFor stackPath;
      };
    }
  ) (lib.filesystem.readDir stackRoot);
in
# A stack can return null when it does not support the target platform
lib.attrsets.filterAttrs (_: package: package != null) packages
