{ pkgs }:

let
  inherit (pkgs) lib;

  stackPackages = pkgs.callPackages ./stack-packages.nix { };

  brew-patches =
    lib.addMetaAttrs
      {
        description = "Browse, validate, and apply the 4evy patch stacks";
        homepage = "https://github.com/4evy/patches";
        license = lib.licenses.mit;
        platforms = lib.platforms.unix;
      }
      (
        pkgs.writers.writeRubyBin "brew-patches" {
          makeWrapperArgs = [
            "--set"
            "PATH"
            (lib.makeBinPath [ pkgs.git ])
            "--set"
            "RUBYOPT"
            "--disable-gems"
            "--unset"
            "RUBYLIB"
            "--set-default"
            "PATCHES_STACKS"
            "${../stacks}"
          ];
        } ../cmd/brew-patches.rb
      );
in

{
  inherit brew-patches stackPackages;

  all = [
    brew-patches
  ]
  ++ lib.attrVals [
    "actionlint"
    "docker-client"
    "docker-compose"
    "direnv"
    "git"
    "hadolint"
    "just"
    "nodejs_26"
    "nix"
    "nix-direnv"
    "npins"
    "pre-commit"
    "prettier"
    "quilt"
    "ruby"
    "shellcheck"
    "shfmt"
    "typescript"
  ] pkgs;
}
