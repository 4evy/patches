{
  sources ? import ./npins,
  system ? builtins.currentSystem,
  pkgs ? import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [ ];
  },
}:

pkgs.mkShell {
  packages = (pkgs.callPackage ./nix/packages.nix { }).all;

  PRETTIER_CONFIG = ./.prettierrc.json;
  RUBYOPT = "--disable-gems";
}
