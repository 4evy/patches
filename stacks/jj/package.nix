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
    hash = "sha256-N62HmkpKrfUgzEWugwYe90f1xwJRit/OaGT81FDJ/rM=";
  };
in
jujutsu.overrideAttrs (oldAttrs: {
  pname = "jj-patched";
  version = "${oldAttrs.version}+git.${builtins.substring 0 12 revision}";
  src = source;
  patches = (oldAttrs.patches or [ ]) ++ patches;
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = source;
    hash = "sha256-Ll7n0olgbWlaNO7aeREzUZVSmYGYLRz3JG0YohmcME0=";
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
