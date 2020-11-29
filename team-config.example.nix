{ boxIp, name, logo ? null, ... }:

{ lib, pkgs, ... }:

with lib;
{
  adLib.teamHost = {
    enable = true;
    name = name;
    logo = logo;
  };

  adLib.p2pTunnels.ipAddress = boxIp;
  adLib.p2pTunnels.uploadLimit = 10240;

  adLib.teamNetwork.vpnSubnet = "10.13.37.0";

  adLib.vulnbox = {
    hostAddress = "10.31.33.1";
    guestAddress = "10.31.33.7";

    image = pkgs.requireFile {
      name = "vulnbox.qcow2.gz";
      message = ''
        Provide vulnbox image with:
          nix-store --add-fixed sha256 vulnbox.qcow2.gz
      '';
      # Change sha256 sum to checksum of your vulnbox.
      sha256 = "d04844cee9565180628123c022f4d814c9c76b8029a41910ab2e99990f4a5202";
    };
  };
}
