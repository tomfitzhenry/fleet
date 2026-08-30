{
  lib,
  buildGoModule,
  fetchFromGitHub,
  git,
}:

buildGoModule (finalAttrs: {
  pname = "llm-curl";
  version = "0-unstable-2026-08-30";

  src = fetchFromGitHub {
    owner = "tomfitzhenry";
    repo = "llm-curl";
    rev = "cb3a9cccc89430a32c77d8a8a4b32a491c5c2a42";
    hash = "sha256-nixGKhNl4i1ijqSUBqWHPfZOf6dwCaVsiUoAhBEXIQ0=";
  };

  # The test suite shells out to git to set up throwaway remote repositories.
  nativeBuildInputs = [ git ];

  # llm-curl has no third-party Go dependencies, so there is nothing to vendor.
  vendorHash = null;

  meta = with lib; {
    description = "A drop-in curl that serves source-code URLs from local git clones instead of the network";
    homepage = "https://github.com/tomfitzhenry/llm-curl";
    mainProgram = "llm-curl";
  };
})
