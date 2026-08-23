{ buildGoModule, lib }:

buildGoModule {
  pname = "btrfs-health";
  version = "0.1.0";
  src = ./.;
  vendorHash = "sha256-pOrn8bbL8JWrA7C/6Ndr7W03ilwhyTW0shc3V9gWuqU=";

  meta = {
    description = "Check btrfs filesystem health and email a report when there are problems";
    mainProgram = "btrfs-health";
    license = lib.licenses.mit;
  };
}
