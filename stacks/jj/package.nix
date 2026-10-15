{
  fetchFromGitHub,
  rustPlatform,
  jujutsu,
  manifest,
  patches,
}:

let
  revision = manifest.source.revision;
  source = fetchFromGitHub {
    owner = "jj-vcs";
    repo = "jj";
    rev = revision;
    hash = "sha256-8BuxLn6nl/iaPmeGDZf+BFvNdqMXKYbDMBGoORBAHps=";
  };
in
jujutsu.overrideAttrs (oldAttrs: {
  pname = "jj-patched";
  version = "${oldAttrs.version}+git.${builtins.substring 0 12 revision}";
  src = source;
  patches = (oldAttrs.patches or [ ]) ++ patches;
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = source;
    inherit patches;
    hash = "sha256-V9sQiAWVAzaSE909n+5M8U3z4MbLYfxF+DkCo6erVOE=";
  };

  # Release packages compile only. Avoid both the Rust test suite and the
  # post-install executable check.
  doCheck = false;
  doInstallCheck = false;
  useNextest = false;

  meta = oldAttrs.meta // {
    description = "Jujutsu built with the 4evy patch stack";
  };
})
