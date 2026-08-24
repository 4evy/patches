{
  description = "Personal patch stacks and their development tools";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      git-hooks,
      nixpkgs,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      forEachSystem = lib.genAttrs systems;

      pkgsFor = system: nixpkgs.legacyPackages.${system};

      packagesFor = system: (pkgsFor system).callPackage ./nix/packages.nix { };

      preCommitFor =
        system:
        git-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            check-json.enable = true;
            end-of-file-fixer = {
              enable = true;
              excludes = [ "\\.patch$" ];
            };
            nixfmt.enable = true;
            prettier = {
              enable = true;
              excludes = [ "\\.patch$" ];
            };
            trim-trailing-whitespace = {
              enable = true;
              excludes = [ "\\.patch$" ];
            };
          };
        };

      fixtureCheck =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.runCommand "4evy-fixture-check"
          {
            nativeBuildInputs = [
              pkgs.git
              pkgs.shellcheck
              pkgs.shfmt
            ];
          }
          ''
            cp -R ${./tests} tests
            chmod -R u+w tests
            shfmt --diff --posix --indent 4 --case-indent --simplify tests/run-fixtures.sh
            shellcheck -x --shell=sh tests/run-fixtures.sh
            sh tests/run-fixtures.sh
            touch $out
          '';

      packageCheck =
        system:
        let
          pkgs = pkgsFor system;
          brew-patches = (packagesFor system).brew-patches;
        in
        pkgs.runCommandLocal "brew-patches-check" { } ''
          ${lib.getExe brew-patches} --help >/dev/null
          GEM_HOME=/does-not-exist \
            GEM_PATH=/does-not-exist \
            RUBYLIB=/does-not-exist \
            RUBYOPT=-w \
            ${lib.getExe brew-patches} validate

          cp -R ${./tests} tests
          chmod -R u+w tests
          . tests/test-support.sh

          create_demo_stack "$PWD" "$PWD/demo"
          cp -R tests/fixtures/multi-file/upstream source

          export PATCHES_STACKS="$PWD/demo/stacks"
          ${lib.getExe brew-patches} check demo source
          ${lib.getExe brew-patches} apply demo source
          grep -q extra_value source/main.c
          touch $out
        '';

      stackPackageExposureCheck =
        system:
        let
          pkgs = pkgsFor system;
          expected = lib.optional pkgs.stdenv.hostPlatform.isLinux "ghostty" ++ [
            "jj"
            "kanata"
          ];
          exposed = builtins.attrNames (packagesFor system).stackPackages;
        in
        assert exposed == expected;
        pkgs.emptyFile;

      moduleTargets = {
        nixos = {
          class = "nixos";
          module = ./modules/nixos.nix;
          optionPath = [
            "environment"
            "systemPackages"
          ];
        };

        "home-manager" = {
          class = "homeManager";
          module = ./modules/home-manager.nix;
          optionPath = [
            "home"
            "packages"
          ];
        };

        darwin = {
          class = "darwin";
          module = ./modules/darwin.nix;
          optionPath = [
            "environment"
            "systemPackages"
          ];
        };
      };

      moduleCheck =
        system:
        {
          class,
          module,
          optionPath,
        }:
        let
          pkgs = pkgsFor system;
          evaluated = lib.evalModules {
            inherit class;
            specialArgs = { inherit pkgs; };
            modules = [
              module
              {
                options = lib.setAttrByPath optionPath (
                  lib.mkOption {
                    type = lib.types.listOf lib.types.package;
                    default = [ ];
                  }
                );
              }
            ];
          };
          enabled = evaluated.extendModules {
            modules = [
              {
                programs._4evy.enable = true;
              }
            ];
          };
          customized = evaluated.extendModules {
            modules = [
              {
                programs._4evy.enable = true;
                programs._4evy.packages = [ pkgs.hello ];
              }
            ];
          };
          packagePathsAt =
            evaluation: map (package: package.outPath) (lib.getAttrFromPath optionPath evaluation.config);
          configuredPackagePaths =
            evaluation: map (package: package.outPath) evaluation.config.programs._4evy.packages;
          defaultBrewPatchesPath = (packagesFor system).brew-patches.outPath;
        in
        assert packagePathsAt evaluated == [ ];
        assert lib.elem defaultBrewPatchesPath (configuredPackagePaths enabled);
        assert packagePathsAt enabled == configuredPackagePaths enabled;
        assert packagePathsAt customized == [ pkgs.hello.outPath ];
        assert configuredPackagePaths customized == [ pkgs.hello.outPath ];
        pkgs.emptyFile;

      moduleChecksFor =
        system:
        lib.mapAttrs' (
          name: moduleTarget: lib.nameValuePair "${name}-module" (moduleCheck system moduleTarget)
        ) moduleTargets;
    in
    {
      nixosModules.default = ./modules/nixos.nix;
      homeManagerModules.default = ./modules/home-manager.nix;
      darwinModules.default = ./modules/darwin.nix;

      packages = forEachSystem (
        system:
        let
          packages = packagesFor system;
        in
        {
          default = packages.brew-patches;
          inherit (packages) brew-patches;
        }
        // packages.stackPackages
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = pkgsFor system;
          pre-commit-check = preCommitFor system;
        in
        {
          default = pkgs.mkShell {
            packages = (packagesFor system).all ++ pre-commit-check.enabledPackages;
            PRETTIER_CONFIG = ./.prettierrc.json;
            RUBYOPT = "--disable-gems";
            inherit (pre-commit-check) shellHook;
          };
        }
      );

      checks = forEachSystem (
        system:
        {
          pre-commit = preCommitFor system;
          fixtures = fixtureCheck system;
          brew-patches = packageCheck system;
          stack-packages = stackPackageExposureCheck system;
        }
        // moduleChecksFor system
        // lib.optionalAttrs (system == "x86_64-linux") {
          nixos-vm = (pkgsFor system).testers.runNixOSTest {
            imports = [ ./tests/nixos-module.nix ];
          };
        }
      );

      formatter = forEachSystem (system: (pkgsFor system).nixfmt-tree);
    };
}
