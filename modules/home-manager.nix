{
  config,
  lib,
  ...
}:

let
  cfg = config.programs._4evy;
in
{
  _class = "homeManager";
  imports = [ ./common.nix ];

  config = lib.mkIf cfg.enable {
    home.packages = cfg.packages;
  };
}
