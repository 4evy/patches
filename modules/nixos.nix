{
  config,
  lib,
  ...
}:

let
  cfg = config.programs._4evy;
in
{
  _class = "nixos";
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = cfg.packages;
  };
}
