{ pkgs, ... }:
{
  name = "4evy-nixos-module";

  nodes = {
    machine = {
      imports = [ ../modules/nixos.nix ];

      virtualisation.cores = 2;
      virtualisation.memorySize = 2048;
      environment.etc."4evy-repo".source = ../.;
      programs._4evy.enable = true;
    };

    customized = {
      imports = [ ../modules/nixos.nix ];

      virtualisation.cores = 2;
      virtualisation.memorySize = 1024;
      programs._4evy = {
        enable = true;
        packages = [ pkgs.hello ];
      };
    };

    disabled.imports = [ ../modules/nixos.nix ];
  };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    disabled.wait_for_unit("multi-user.target")
    customized.wait_for_unit("multi-user.target")

    for command in [
        "actionlint",
        "docker",
        "direnv",
        "git",
        "hadolint",
        "just",
        "node",
        "nix",
        "npins",
        "pre-commit",
        "prettier",
        "quilt",
        "ruby",
        "shellcheck",
        "shfmt",
        "tsc",
    ]:
        machine.succeed(f"command -v {command}")

    for command in [
        "direnv version",
        "git --version",
        "hadolint --version",
        "just --version",
        "node --version",
        "nix --version",
        "npins --version",
        "pre-commit --version",
        "prettier --version",
        "quilt --version",
        "ruby --version",
        "shellcheck --version",
        "shfmt --version",
        "tsc --version",
    ]:
        machine.succeed(command)

    machine.succeed("docker compose version")
    machine.succeed("test -x \"$(command -v brew-patches)\"")
    machine.succeed("brew-patches --help")
    machine.succeed("brew-patches list >/tmp/packaged-stacks")
    machine.succeed(
        "ruby /etc/4evy-repo/cmd/brew-patches.rb list >/tmp/repository-stacks"
    )
    machine.succeed("diff -u /tmp/repository-stacks /tmp/packaged-stacks")
    machine.succeed("! brew-patches unknown >/tmp/brew-patches-error 2>&1")
    machine.succeed("grep -q 'Unknown arguments' /tmp/brew-patches-error")
    machine.succeed("just --justfile /etc/4evy-repo/Justfile --list")
    machine.succeed("ruby -c /etc/4evy-repo/cmd/brew-patches.rb")
    machine.succeed(
        "node -e 'for (const file of process.argv.slice(1)) JSON.parse(require(\"fs\").readFileSync(file))' "
        "/etc/4evy-repo/package.json "
        "/etc/4evy-repo/schema/stack-v1.schema.json"
    )
    machine.succeed(
        "docker compose -f /etc/4evy-repo/compose.yaml config >/tmp/compose-config"
    )
    machine.succeed(
        "prettier --check /etc/4evy-repo/package.json /etc/4evy-repo/schema/stack-v1.schema.json"
    )
    machine.succeed(
        "shfmt --diff --posix --indent 4 --case-indent --simplify /etc/4evy-repo/tests/run-fixtures.sh"
    )
    machine.succeed("actionlint /etc/4evy-repo/.github/workflows/check.yml")
    machine.succeed("/etc/4evy-repo/tests/run-fixtures.sh")

    # The module installs clients only; it must not silently enable daemons.
    machine.succeed("direnv stdlib >/tmp/direnv-stdlib")
    machine.succeed("test ! -e /run/current-system/sw/bin/dockerd")
    machine.succeed("! systemctl list-unit-files --type=service | grep -q '^docker.service'")

    disabled.succeed("! command -v brew-patches")
    disabled.succeed("! command -v hello")
    customized.succeed("command -v hello")
    customized.succeed("! command -v brew-patches")
  '';
}
