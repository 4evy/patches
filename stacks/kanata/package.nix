{
  applyPatches,
  fetchFromGitHub,
  kanata,
  manifest,
  patches,
  rustPlatform,
}:

let
  revision = manifest.source.revision;
  source = fetchFromGitHub {
    owner = "jtroo";
    repo = "kanata";
    rev = revision;
    hash = "sha256-O3cKyJ352/miOr2sTnO7ZmKz4dJKYSH6iQZo9ELDIms=";
  };
  patchedSource = applyPatches {
    name = "kanata-${builtins.substring 0 12 revision}-patched-source";
    src = source;
    inherit patches;
  };
in
kanata.overrideAttrs (oldAttrs: {
  pname = "kanata-patched";
  version = "1.12.1-prerelease-1+git.${builtins.substring 0 12 revision}";
  src = patchedSource;
  patches = oldAttrs.patches or [ ];
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = patchedSource;
    hash = "sha256-QbxpUX8z1vrgVEiPTLs5ah6+qqMtZGJgbMPSYXACr10=";
  };

  # Release packages compile only. Tests exercise hardware-facing behavior and
  # belong in dedicated upstream environments, not this distributable build.
  doCheck = false;
  doInstallCheck = false;

  meta = oldAttrs.meta // {
    description = "Kanata built with the 4evy patch stack";
  };
})
