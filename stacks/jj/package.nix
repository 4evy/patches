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
    hash = "sha256-mt2YeDeLvZ+yaiKDpFOaNxnQ37Bi4CQHpyyxNGmJpQE=";
  };
in
jujutsu.overrideAttrs (oldAttrs: {
  pname = "jj-patched";
  version = "${oldAttrs.version}+git.${builtins.substring 0 12 revision}";
  src = source;
  patches = (oldAttrs.patches or [ ]) ++ patches;
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = source;
    hash = "sha256-0kFJ/riOnf/Puw9dWmvRW0B21YFN2S3+udZUvaYHv5I=";
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
