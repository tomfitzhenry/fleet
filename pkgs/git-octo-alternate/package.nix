{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:

buildGoModule (finalAttrs: {
  pname = "git-octo-alternate";
  version = "0-unstable-2026-08-31";

  src = fetchFromGitHub {
    owner = "tomfitzhenry";
    repo = "git-octo-alternate";
    rev = "b0aa95c879ecd7f1b28ef640883dc8080497aab5";
    hash = "sha256-eJZULY5xl1opxk6y/FvIKJoZLmsYArxhZLebYclEDqQ=";
  };

  # The test suite shells out to git to set up throwaway remote repositories.
  nativeBuildInputs = [ git ];

  # git-octo-alternate has no third-party Go dependencies, so there is nothing
  # to vendor.
  vendorHash = null;

  meta = with lib; {
    description = "Manage a shared git alternates store containing many embedded repositories";
    homepage = "https://github.com/tomfitzhenry/git-octo-alternate";
    mainProgram = "git-octo-alternate";
  };
})
