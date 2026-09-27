# S3-backed Nix binary cache (https://github.com/Mic92/niks3).
#
# Import this module only on the machine that should run the cache; importing
# it pulls in the third-party niks3 flake module.
#
# Secrets are managed manually, like the rest of the fleet. Create these files
# on the host:
#   /etc/niks3/api-token       API token (>= 36 chars), e.g. `openssl rand -hex 32`
#   /etc/niks3/signing-key     Nix cache signing key (Ed25519)
#   /etc/niks3/r2-access-key   Cloudflare R2 access key ID
#   /etc/niks3/r2-secret-key   Cloudflare R2 secret access key
#
# Generate the signing key and its public counterpart:
#   nix key generate-secret --key-name niks3 > /etc/niks3/signing-key
#   nix key convert-secret-to-public < /etc/niks3/signing-key
{ niks3, ... }:
{
  imports = [ niks3.nixosModules.niks3 ];

  services.niks3 = {
    enable = true;

    apiTokenFile = "/etc/niks3/api-token";
    signKeyFiles = [ "/etc/niks3/signing-key" ];

    # Public URL the cache is read from; used to generate the landing page.
    cacheUrl = "https://pub-13e2bc6cc8cf4f34a8cf144e466d114e.r2.dev";

    s3 = {
      # Cloudflare R2 S3 API endpoint (account ID from the Cloudflare dashboard,
      # https://developers.cloudflare.com/r2/). Scheme is omitted: the module
      # sets --s3-use-ssl=true, so minio-go derives https from the host.
      endpoint = "596e7fbff2bad4f39e40d573606c2193.r2.cloudflarestorage.com";
      bucket = "niks3";
      region = "auto"; # R2 requires region "auto" for request signing.
      accessKeyFile = "/etc/niks3/r2-access-key";
      secretKeyFile = "/etc/niks3/r2-secret-key";
    };
  };
}
