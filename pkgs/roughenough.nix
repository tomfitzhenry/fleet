{ lib, fetchFromGitHub, rustPlatform }:

rustPlatform.buildRustPackage rec {
  pname = "roughenough";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "int08h";
    repo = "roughenough";
    rev = "04ca59bf321b46b650574aa9e67900f1a9c216a5";
    hash = "sha256-DvHgjwNY2GdDqcqhw66AJaMbJFWiHxmaVct1hYI/h50=";
  };

  cargoHash = "sha256-4UyTLSOv0EI9b9WJ8fcb/M8W9NWErbqLIy+//BcF9MA=";

  patches = [ ./roughenough-logging.patch ];

  # The workspace's default members build the server, client and key tool.
  # The reporting server (axum/tokio web stack) is intentionally excluded.
  doCheck = false;

  meta = {
    description = "RFC 10049 Roughtime server and client";
    homepage = "https://github.com/int08h/roughenough";
    license = with lib.licenses; [ asl20 mit ];
    maintainers = [ ];
    mainProgram = "roughenough_server";
  };
}
