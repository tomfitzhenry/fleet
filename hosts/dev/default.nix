{
  system.stateVersion = "25.05";

  microvm = {
    vcpu = 6;
    mem = 12 * 1024;
  };

  tomf.sshd = {
    enable = true;
    openFirewall = true;
  };
}
