{
  config,
  lib,
  ...
}:

let
  cfg = config.programs._4evy;
in
{
  _class = "darwin";
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    environment.systemPackages = cfg.packages;
  };
}
