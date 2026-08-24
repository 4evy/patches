{
  callPackage,
  fetchFromGitHub,
  stdenv,
  manifest,
  patches,
}:

if !stdenv.hostPlatform.isLinux then
  null
else
  let
    revision = manifest.source.revision;
    source = fetchFromGitHub {
      owner = "ghostty-org";
      repo = "ghostty";
      rev = revision;
      hash = "sha256-28tDNkJ0sLzogMuCrILCLNakIG/bTqyKgBw7Axziv+M=";
    };
  in
  (callPackage (source + "/nix/package.nix") {
    optimize = "ReleaseFast";
    revision = builtins.substring 0 12 revision;
  }).overrideAttrs
    (oldAttrs: {
      # Use the complete checkout because this stack also patches macOS source.
      src = source;
      patches = (oldAttrs.patches or [ ]) ++ patches;

      # Release packages compile only. Tests and install checks belong to the
      # development checks, not this distributable derivation.
      doCheck = false;
      doInstallCheck = false;

      meta = oldAttrs.meta // {
        description = "Ghostty built with the 4evy patch stack";
      };
    })
