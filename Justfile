set minimum-version := "1.58.0"
set shell := ["sh", "-eu", "-c"]

alias c := check
alias f := fmt
alias h := hooks-install

# Show the available recipes.
default: list

# Show the available recipes.
[group('help')]
list:
    @just --list

# Format all files owned by the repository's root tooling.
[group('format')]
fmt:
    npm run format
    tests/shell-quality.sh --write
    just --fmt

# Check formatting without changing files.
[group('check')]
fmt-check:
    npm run format:check

# Check that npm can reproduce the Node.js dependency tree.
[group('check')]
npm-check:
    npm ci --ignore-scripts

# Format Nix files with the flake formatter.
[group('format')]
nix-fmt:
    nix fmt

# Check the flake and its exported modules.
[group('check')]
nix-check:
    nix flake check --no-write-lock-file

# Run every configured pre-commit hook.
[group('check')]
hooks-check:
    if test -f .pre-commit-config.yaml && \
        command -v pre-commit >/dev/null; then \
        pre-commit run --all-files; \
    else \
        nix develop -c pre-commit run --all-files; \
    fi

# Check the Justfile itself.
[group('check')]
just-check:
    just --fmt --check

# Check POSIX shell syntax, formatting, and portability.
[group('check')]
shell-check:
    tests/shell-quality.sh

# Check the Homebrew command syntax.
[group('check')]
cli-syntax-check:
    ruby -c cmd/brew-patches.rb

# Exercise catalog validation and the non-mutating/apply workflow.
[group('check')]
cli-check:
    sh tests/cli-check.sh

# Typecheck, build, and exercise the runtime website and JSON endpoints.
[group('check')]
website-check:
    npm run check
    npm run test
    npm run build
    npm run test:website

# Apply every language fixture patch to a clean source copy.
[group('check')]
fixtures-check:
    tests/run-fixtures.sh

# Fetch each pinned upstream and check its real patch queue.
[group('check')]
stacks-check *stacks:
    tests/stack-check.sh {{ stacks }}

# Evaluate the Guix package, manifest, Home, System, and channel definitions
# when Guix is installed. The dedicated Guix GitHub Actions job supplies it.
[group('check')]
guix-check:
    if command -v guix >/dev/null; then guix repl -L packaging/guix -L guix -- tests/guix-check.scm; guix repl -L packaging/guix -L guix -- guix/four-evy/manifest.scm; guix repl -L guix -- guix/four-evy/channels.scm; else echo 'Guix is unavailable; skipping Guix validation'; fi

# Validate GitHub Actions workflow definitions.
[group('check')]
actions-check:
    actionlint .github/workflows/*.yml

# Validate the container definitions.
[group('check')]
container-check:
    hadolint Dockerfile
    tests/container-check.sh

# Run the checks that do not modify the working tree.
[group('check')]
check: npm-check fmt-check hooks-check nix-check just-check shell-check cli-syntax-check cli-check website-check fixtures-check stacks-check guix-check actions-check container-check

# Run checks that do not require Nix or Guix.
[group('check')]
core-check: npm-check fmt-check just-check cli-syntax-check cli-check website-check fixtures-check

[group('check')]
tooling-check: core-check container-check

# Install the Git hooks into this checkout.
[group('dependencies')]
hooks-install:
    if test -f .pre-commit-config.yaml && \
        command -v pre-commit >/dev/null; then \
        pre-commit install; \
    else \
        nix develop -c pre-commit install; \
    fi

# Show the tools and versions used by this repository.
[group('help')]
doctor:
    nix --version
    just --version
    ruby --version
    node --version
    npm --version
    prettier --version
    pre-commit --version

# Update all pinned dependencies.
[group('dependencies')]
update: flake-update npins-update npm-update

# Update flake inputs.
[group('dependencies')]
flake-update:
    nix flake update

# Refresh the npm lockfile.
[group('dependencies')]
npm-update:
    npm install --package-lock-only --ignore-scripts

# Enter the flake development shell.
[group('shell')]
shell:
    nix develop

# Enter the classic Nix development shell.
[group('shell')]
shell-classic:
    nix-shell

# Update pinned sources with npins.
[group('dependencies')]
npins-update:
    npins update
