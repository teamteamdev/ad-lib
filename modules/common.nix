{ config, pkgs, lib, ... }:

with lib;
{
  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
    };

    # Use sandboxed builds.
    useSandbox = true;
  };

  networking.nameservers = [ "1.1.1.1" "1.0.0.1" ];

  networking.firewall.checkReversePath = true;

  boot = {
    cleanTmpDir = true;
  };

  # Time zone
  time.timeZone = "Europe/Moscow";

  # Security
  security = {
    sudo.extraConfig = ''
      Defaults rootpw,insults,timestamp_timeout=60
    '';

    pam.services.su.forwardXAuth = mkForce false;
  };

  services = {
    openssh = {
      enable = true;
      passwordAuthentication = false;
    };
  };

  documentation.nixos.enable = false;

  # Packages
  environment = {
    systemPackages = (with pkgs; [
      # Monitors
      htop
      iotop
      ftop
      nethogs
      psmisc
      lsof

      # Files
      zip
      unzip
      tree
      rsync
      file
      pv
      dos2unix

      # Editors
      vim
      pastebinit

      # Runtimes
      python3 # inconsistent

      # Develompent
      git

      # Networking
      inetutils
      dnsutils
      aria2
      socat
      mtr
      tcpdump

      # Utilities
      screen
      parallel
      mkpasswd
    ]);
  };

  fonts.fontconfig.enable = false;

  services.postgresql.package = pkgs.postgresql_13;

  programs.ssh = {
    setXAuthLocation = false;
    extraConfig = ''
      ServerAliveInterval 60
    '';
  };

  users.mutableUsers = false;

  system.stateVersion = "20.09";
}
