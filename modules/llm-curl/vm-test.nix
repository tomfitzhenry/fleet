# NixOS VM test for the llm-curl module: the user's curl resolves to llm-curl,
# which serves a recognized source URL from a local git clone under the ghq
# root (~/ghq); real-curl is the real curl. Fall-through to the real curl
# needs a network, so identity checks stand in for it.
{ pkgs, ... }:
{
  name = "llm-curl";

  nodes.machine =
    { ... }:
    {
      imports = [ ./. ];

      users.users.dev = {
        isNormalUser = true;
      };

      tomf.llm-curl = {
        enable = true;
        user = "dev";
      };

      # llm-curl shells out to git and ghq to locate clones, and to the real
      # curl on fall-through.
      environment.systemPackages = [
        pkgs.git
        pkgs.ghq
        pkgs.curl
      ];
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # curl is the llm-curl binary; real-curl is the real curl.
    curl_target = machine.succeed(
        "su - dev -c 'readlink -f $(command -v curl)'").strip()
    realcurl_target = machine.succeed(
        "su - dev -c 'readlink -f $(command -v real-curl)'").strip()
    assert "llm-curl" in curl_target, curl_target
    assert "llm-curl" not in realcurl_target, realcurl_target

    # A recognized source URL is served from a local clone, not the network.
    machine.succeed(
        "su - dev -c 'mkdir -p /home/dev/ghq/github.com/torvalds/linux'")
    machine.succeed(
        "su - dev -c 'cd /home/dev/ghq/github.com/torvalds/linux && "
        + "git init -qb master && "
        + "git remote add origin https://github.com/torvalds/linux.git && "
        + "git config user.email test@test.invalid && "
        + "git config user.name test'")
    machine.succeed(
        "su - dev -c 'cd /home/dev/ghq/github.com/torvalds/linux && "
        + 'printf "hello from the local clone" > README && '
        + "git add README && git commit -qm init'")
    out = machine.succeed(
        "su - dev -c 'curl -sL "
        + "https://raw.githubusercontent.com/torvalds/linux/master/README'")
    assert "hello from the local clone" in out, out
  '';
}
