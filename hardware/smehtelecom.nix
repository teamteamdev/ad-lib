{ config, lib, pkgs, ... }:

{

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [ "mptspi" ];

  fileSystems."/" = { device = "/dev/sda2"; fsType = "ext4"; };
  fileSystems."/boot" = { device = "/dev/sda1"; fsType = "vfat"; };

  swapDevices = [ ];

  nix.maxJobs = lib.mkDefault 2;

  networking.interfaces.ens160.useDHCP = true;
  adLib.externalInterface = "ens160";

  virtualisation.vmware.guest = {
    enable = true;
    headless = true;
  };
}
