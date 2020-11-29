{ boxIp, email, hostName, ... }@args:

{ pkgs, ... }:

let
  callChecker = path: pkgs.python3.pkgs.callPackage path {
    # If you want to, clone https://github.com/ugractf/ad-checklib and use it here.
    # adchecklib = pkgs.python3.pkgs.callPackage ./ad-checklib { };
  };

in {
  imports = [ (import ./adhell-config.nix args) (import ./tollfree-config.nix args) ];

  adLib.juryHost = {
    enable = true;
    hostName = hostName;
  };

  adLib.p2pTunnels.ipAddress = boxIp;

  security.acme.email = email;

  adLib.checksystem = {
    name = "Example CTF";
    times = [ { from = "2020-11-24 13:00:00"; to = "2020-11-24 17:30:00"; } ];
    roundLength = 120;
    flagLifeTime = 4;
    services = {
      service1 = {
        path = callChecker ./example-checker.nix;
        tcpPort = 9009;
        timeout = 40;
      };
      service2 = {
        path = callChecker ./other-example-checker.nix;
        tcpPort = 8600;
      };
    };
  };
}
