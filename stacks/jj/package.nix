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
    hash = "sha256-h2ipjJASTvjmSgKo0kwU/eHzV8DV0O8KQwuZK83cKBA=";
  };
in
jujutsu.overrideAttrs (oldAttrs: {
  pname = "jj-patched";
  version = "${oldAttrs.version}+git.${builtins.substring 0 12 revision}";
  src = source;
  patches = (oldAttrs.patches or [ ]) ++ patches;
  cargoDeps = rustPlatform.fetchCargoVendor {
    src = source;
    hash = "sha256-yHk2QzU+F2Qdv/gp50VMQD8sJBvrQxjRJrVBaAFl7/U=";
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
