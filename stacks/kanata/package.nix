{
  applyPatches,
  fetchFromGitHub,
  kanata,
  lib,
  manifest,
  patches,
  pkg-config,
  rustPlatform,
  stdenv,
  udev,
}:

let
  revision = manifest.source.revision;
  source = fetchFromGitHub {
    owner = "jtroo";
    repo = "kanata";
    rev = revision;
    hash = "sha256-aaGzlj/VAYJfTdOK41iokhufvlBVqusLyh8JwAQkBJA=";
  };
  patchedSource = applyPatches {
    name = "kanata-${builtins.substring 0 12 revision}-patched-source";
    src = source;
    inherit patches;
  };
in
kanata.overrideAttrs (oldAttrs: {
  pname = "kanata-patched";
  version = "1.13.0-prerelease-2+git.${builtins.substring 0 12 revision}";
  src = patchedSource;
  patches = oldAttrs.patches or [ ];
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = patchedSource;
    hash = "sha256-9HfETrrZQuobMkU5/rVlRUJ+4oJC+Qwyn9/B63A3UV8=";
  };

  # Gamepad support needs libudev on Linux
  nativeBuildInputs =
    (oldAttrs.nativeBuildInputs or [ ]) ++ lib.optionals stdenv.hostPlatform.isLinux [ pkg-config ];
  buildInputs = (oldAttrs.buildInputs or [ ]) ++ lib.optionals stdenv.hostPlatform.isLinux [ udev ];

  # Release packages compile only. Tests exercise hardware-facing behavior and
  # belong in dedicated upstream environments, not this distributable build.
  doCheck = false;
  doInstallCheck = false;

  meta = oldAttrs.meta // {
    description = "Kanata built with the 4evy patch stack";
  };
})
