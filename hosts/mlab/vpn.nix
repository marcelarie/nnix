# Setup:
# 1. Generate a WireGuard config at https://mullvad.net/en/account/wireguard-config
#    (any server; pick one with port forwarding if you want qbit's peer port reachable from the internet).
# 2. sops secrets/mlab.yaml -> add `mullvad_wg_conf: |` with the full file
#    content pasted in, indented.
# 3. nixos-rebuild switch --flake .#mlab
#
# qBittorrent's peer port (was 23951, opened in default.nix) no longer needs
# a host firewall entry - it's not reachable there any more, since qbit now
# only listens inside this namespace. If you enable port forwarding on your
# Mullvad account, set qBittorrent's WebUI "Listening Port" to the forwarded
# port and uncomment openVPNPorts below with that same port.
{
  config,
  lib,
  services,
  ...
}: {
  sops.secrets."mullvad_wg_conf" = {};

  vpnNamespaces.mullvad = {
    enable = true;
    wireguardConfigFile = config.sops.secrets."mullvad_wg_conf".path;
    # One portMapping per proxy.nix service marked `vpn = true` - keeps the
    # port list in one place instead of duplicating it here.
    portMappings = lib.pipe services [
      (lib.filterAttrs (_: s: s.vpn or false))
      (lib.mapAttrsToList (_: s: {
        from = s.port;
        to = s.port;
      }))
    ];
    # openVPNPorts = [{port = <mullvad forwarded port>; protocol = "both";}];
  };

  systemd.services = let
    confined = {
      enable = true;
      vpnNamespace = "mullvad";
    };
  in {
    qbittorrent.vpnConfinement = confined;
    sabnzbd.vpnConfinement = confined;
    sonarr.vpnConfinement = confined;
    radarr.vpnConfinement = confined;
    lidarr.vpnConfinement = confined;
    bazarr.vpnConfinement = confined;
    prowlarr.vpnConfinement = confined;
    "podman-chaptarr".vpnConfinement = confined;
    "podman-buildarr".vpnConfinement = confined;
    invidious.vpnConfinement = confined;
    "podman-invidious-companion".vpnConfinement = confined;
  };
}
