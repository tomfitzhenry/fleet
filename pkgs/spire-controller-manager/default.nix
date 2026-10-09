# SPIRE Controller Manager, pinned to the v0.8.0 release.
#
# Only the `cmd` binary is needed: in "Static Mode" (staticManifestPath set)
# it reads ClusterStaticEntry YAML from disk and reconciles them onto a SPIRE
# server over its local unix socket. No Kubernetes API access is required.
#
# Upstream: https://github.com/spiffe/spire-controller-manager
{
  lib,
  buildGo127Module,
  fetchFromGitHub,
}:

buildGo127Module (finalAttrs: {
  pname = "spire-controller-manager";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "spiffe";
    repo = "spire-controller-manager";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Uyh9XdqKiTSzgO2Y2wFhtWZSl9F9/63qZEMrfrnH4Ug=";
  };

  # v0.8.0 falls through from staticRun() into run() after SIGTERM, re-calling
  # ctrl.SetupSignalHandler() and panicking with "close of closed channel".
  # Exit after a clean static-mode shutdown instead. Unfixed in upstream main
  # as of 03b4f44 (the only commit since v0.8.0 is a dependency bump).
  patches = [ ./shutdown-panic.patch ];

  vendorHash = "sha256-Xid0cD6xW1f4tc3U89e66E6wpxCNsuclislg4pRzWRM=";

  subPackages = [ "cmd" ];

  # Static binary, as upstream's Dockerfile does (ENV CGO_ENABLED=0).
  env.CGO_ENABLED = 0;

  # `cmd` installs as `$out/bin/cmd`; give it the upstream name.
  postInstall = ''
    mv $out/bin/cmd $out/bin/spire-controller-manager
  '';

  # The test suite drives envtest (kube-apiserver/etcd), which is not
  # available in the sandbox.
  doCheck = false;

  meta = {
    description = "A Kubernetes controller to manage SPIRE registration entries, usable without Kubernetes in Static Mode";
    homepage = "https://github.com/spiffe/spire-controller-manager";
    changelog = "https://github.com/spiffe/spire-controller-manager/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    mainProgram = "spire-controller-manager";
    platforms = lib.platforms.linux;
  };
})
