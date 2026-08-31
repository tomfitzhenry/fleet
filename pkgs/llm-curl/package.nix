{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:

buildGoModule (finalAttrs: {
  pname = "llm-curl";
  version = "0-unstable-2026-08-31";

  src = fetchFromGitHub {
    owner = "tomfitzhenry";
    repo = "llm-curl";
    rev = "9589719733c9f56460c128944044d57e54f0f011";
    hash = "sha256-ejYpQ90qWm8mFoCgDKepntEwiujUGkek0B/qeaTkcP0=";
  };

  # The test suite shells out to git to set up throwaway remote repositories.
  nativeBuildInputs = [ git ];

  # The test suite shells out to git to set up throwaway remote repositories,
  # and clones with --reference against the git-octo-alternate store, so point
  # that at an empty local repo.
  preCheck = ''
    export GIT_OCTO_ALTERNATE_STORE=$TMPDIR/octo-alternate-store
    git init -q --bare $GIT_OCTO_ALTERNATE_STORE
  '';

  # llm-curl has no third-party Go dependencies, so there is nothing to vendor.
  vendorHash = null;

  meta = with lib; {
    description = "A drop-in curl that serves source-code URLs from local git clones instead of the network";
    homepage = "https://github.com/tomfitzhenry/llm-curl";
    mainProgram = "llm-curl";
  };
})
