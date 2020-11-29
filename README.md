![team Team logo](http://k60.in/public/adlib-logo.svg)

NixOps library for deployment of A—D infrastructure, including team hosts and services by [[team Team]](https://teamteam.dev).

## Design overview

ad-lib implements A—D network as a fully connected network of machines, where each one maintains a set of GRE FOU connections to others. One host is designated as a _jury host_ — it hosts checksystem and service checkers. Other hosts are _team hosts_ — each one runs a vulnbox in a virtual machine. Vulnbox network is isolated — from its perspective, all requests come from a pre-configured IP address. Team hosts also run OpenVPN servers to allow teams to connect and access the internal network. Various limits and restrictions are implemented to improve security and stability of this setup.

### Network

All hosts (team and jury) are accessible via their internal IP addresses (`boxIp` option) from hosts themselves, vulnboxes and team machines. All traffic from team hosts (whether a packet comes from a vulnbox, a team member machine or the host itself) is masqueraded. Team hosts can run various services apart from the vulnbox, configured by organizers, which also access the network. Team member machines are isolated from other teams, but have connectivity between themselves in the VPN. They can access vulnbox and their team host (if additional services are enabled) at fixed configured IP addresses (i.e., each team can access Packmate at the OpenVPN host IP address, and vulnbox at the local virtual network interface IP address).

For team hosts, all packets incoming from other hosts are redirected to their respective vulnboxes. For jury host, the server itself is exposed to the network, and teams can access the checksystem.

### Jury host

We run [Hackerdom checksystem](https://github.com/hackerdom/checksystem) at the jury host. We also capture all network traffic and store it locally at `/var/lib/traffic-dump`.

### Team hosts

We run these services on team hosts:

* Vulnbox, implemented as `libvirtd-qemu` virtual machine;
* OpenVPN server;
* [Packmate](https://gitlab.com/packmate/Packmate) to log vulnbox traffic and make it accessible to the teams;
* [DestructiveFarm](https://github.com/destructivevoice/destructivefarm), exploit farm pre-configured to access the jury host.

We also capture all network traffic unmasqueraded, at the same directory as jury host does. It's unaccessible to the teams, and can be used for investigations.

Team hosts limit outgoing traffic to other teams' hosts to avoid flooding other teams.

## Deployment

You need to read [NixOps manual](https://nixops.readthedocs.io/en/latest/overview.html) first and make yourself comfortable with Nix and NixOps. Example configuration files are provided - see `machines.example.nix` and others. You will also need *N* + 1 hosts for *N* teams and jury, which already have NixOS installed with OpenSSH enabled. Team hosts *must* support virtualization — you can use `virt-host-validate` to verify this. They can use any NixOS version or configuration, as long as SSH is exposed and you can login remotely as root.

You will need a vulnbox image in `.qcow2.gz` format. We recommend to build it locally with libvirtd (see `modules/vulnbox/vulnbox.xml` configuration file). [Shrinking qcow2 image](https://pve.proxmox.com/wiki/Shrink_Qcow2_Disk_Files) also helps.

When everything is configured, run `nixops deploy -d deployment-name`. If you made any changes, just run this command again, and all reconfiguration will happen automatically and will not affect other parts of your configuration (i.e. changes to the Packmate configuration only leads to Packmate restart, and changes in jury configuration don't affect other machines).

After deployment you need to run this once to distribute checksystem tokens between team hosts: `./run-for-teams.sh deployment-name scripts/push-token.sh`.

Then run `./run-for-teams.sh deployment-name scripts/get-client-bundle.sh client-creds`. This generates teams' credentials and places them to `client-creds` directory. You can then distribute them to teams.

Use `nixops ssh-for-each virsh domstate vulnbox` to check that vulnbox is online. You can inspect a vulnbox screen and interact with it remotely using usual libvirtd utilities, e.g. with `virt-manager` over SSH.

## Maintenance scripts

We provide several helpful scripts in `scripts/` subdirectory. You can use these to clear state, clear captured traffic etc. `./run-for-teams.sh` allows you to run these scripts for all team hosts simultaneously. We also recommend to use NixOps management commands, like `ssh-for-each`, `scp`, `reboot` and others.

## Support

Feel free to ask any questions and leave your feedback in our chat: [@teamteamhelps](https://t.me/teamteamhelps).
