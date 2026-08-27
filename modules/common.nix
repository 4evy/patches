{ lib, pkgs, ... }:

let
  defaultPackages = (pkgs.callPackage ../nix/packages.nix { }).all;
in
{
  options.programs._4evy = {
    enable = lib.mkEnableOption "the 4evy patch tools";

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = defaultPackages;
      defaultText = lib.literalMD "the default 4evy development tool set";
      description = ''
        Packages to install for the 4evy patch tools. Set this to customize
        the tool set while retaining the module's enable flag.
      '';
    };
  };
}
