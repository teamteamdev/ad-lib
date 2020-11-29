let
  # Use your own hardware configuration here.
  makeRTMachine = args: { config, pkgs, ... }: {
    imports = [ ./ad-lib/modules/common.nix ./ad-lib/modules/common-deploy.nix ./ad-lib/hardware/smehtelecom.nix ./local-common.nix (args.config or {}) ];
    deployment.targetHost = args.internalIp;
    adLib.internalIp = args.internalIp;
    adLib.externalIp = args.internalIp;
  };

  makeTeamMachine = args: { config, pkgs, ... }@inputs: makeRTMachine (args // {
    config = (import ./team-config.nix args inputs) // (args.config or {});
  }) inputs;

in {
  network = {
    description = "Example deployment";
  };

  jury-host = makeRTMachine {
    externalIp = "195.19.98.222";
    internalIp = "192.168.1.200";
    config = import ./jury-config.nix {
      boxIp = "10.2.0.20";
      hostName = "board.example.com";
      email = "admin@example.com";
    };
  };

  team1-host = makeTeamMachine {
    externalIp = "195.19.98.223";
    internalIp = "192.168.1.1";
    name = "NPC";
    logo = "https://example.com/teams/1.png";
    boxIp = "10.2.2.1";
  };

  team2-host = makeTeamMachine {
    externalIp = "195.19.98.224";
    internalIp = "192.168.1.2";
    logo = "https://example.com/teams/2.png";
    name = "ExampleTeam";
    boxIp = "10.2.2.2";
  };
}
