{
  lib,
  buildGoModule,
  fetchFromGitHub,
  go,
}:

(buildGoModule.override { inherit go; }) (finalAttrs: {
  pname = "nsupdated";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "tomfitzhenry";
    repo = "nsupdated";
    rev = "f6cc5b1137f8055566e4da78d967730e867d95fc";
    hash = "sha256-Zza1DMIVtcnBtZN11p3+rR618kwHJrl2q2sGupwa6bs=";
  };

  vendorHash = "sha256-MOethmzQtLmjsnwIKdfTOKJcoZeFkrZ6G0h5wdM6bQI=";

  meta = with lib; {
    description = "RFC 2136 dynamic updates and AXFR over a Unix socket, backed by any DNSControl provider";
    homepage = "https://github.com/tomfitzhenry/nsupdated";
    license = licenses.mit;
    mainProgram = "nsupdated";
  };
})
