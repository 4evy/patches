{ callPackage, lib }:

let
  stackRoot = ../stacks;

  patchesFor =
    stackPath:
    let
      patchRoot = lib.path.append stackPath "patches";
      lines = lib.splitString "\n" (builtins.readFile (lib.path.append patchRoot "series"));
      matchPatch = line: builtins.match "[[:space:]]*([^#[:space:]]+).*" line;
      matches = builtins.filter (match: match != null) (map matchPatch lines);
    in
    map (match: lib.path.append patchRoot (lib.head match)) matches;

  callStackPackage =
    packagePath: overrides:
    let
      stackPath = dirOf packagePath;
    in
    callPackage packagePath (
      overrides
      // {
        manifest = lib.importJSON (lib.path.append stackPath "stack.json");
        patches = patchesFor stackPath;
      }
    );

  discoveredPackages = lib.packagesFromDirectoryRecursive {
    callPackage = callStackPackage;
    directory = stackRoot;
  };
in
lib.filterAttrs (_: lib.isDerivation) discoveredPackages
