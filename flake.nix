{
  description = "Personal patch stacks and patched Nix packages";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forEachSystem = lib.genAttrs systems;

      stackSources =
        lib.mapAttrs
          (
            name: _:
            let
              manifest = lib.importJSON (./stacks + "/${name}/stack.json");
            in
            {
              inherit (manifest.source)
                canonical
                revision
                trackingRef
                vcs
                ;
            }
          )
          (
            lib.filterAttrs (
              name: type: type == "directory" && builtins.pathExists (./stacks + "/${name}/stack.json")
            ) (builtins.readDir ./stacks)
          );
    in
    {
      inherit stackSources;

      packages = forEachSystem (
        system: nixpkgs.legacyPackages.${system}.callPackages ./nix/stack-packages.nix { }
      );

      formatter = forEachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
