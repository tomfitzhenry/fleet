{
  lib,
  buildGoModule,
  fetchFromGitea,
  testers,
}:

buildGoModule (finalAttrs: {
  pname = "gonemaster";
  version = "1.6.0";

  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "pawal";
    repo = "gonemaster";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ufoyusyQY5jm9zbs75ukehLgOt73Q5w6f2AAa/PqnO0=";
  };

  vendorHash = "sha256-ASrTpOUURL0bEPrUVsidrj0SMrDamNHvW6M2cjl6brI=";

  tags = [ "nogui" ];

  doCheck = false;

  passthru.tests.version = testers.testVersion {
    package = finalAttrs.finalPackage;
    command = "${lib.getExe finalAttrs.finalPackage} --version | sed -n '1s/^.*v//p'";
  };

  meta = with lib; {
    description = "A comprehensive DNS delegation health checker with scoring, cohort analysis, and monitoring plugins";
    homepage = "https://codeberg.org/pawal/gonemaster";
    license = licenses.bsd2;
    mainProgram = "gonemaster";
    maintainers = with maintainers; [ tomfitzhenry ];
  };
})
