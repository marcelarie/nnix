{
  config,
  lib,
  services,
  ...
}: {
  # The live config is /var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
  # (the service runs with --profile=/var/lib/qBittorrent) and is NOT managed by
  # nix - a sops template here would be written to a path the service never reads.
  # Edit settings in the WebUI; they persist on exit.

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent 0775 qbittorrent media -"
    "d /var/lib/qbittorrent/.config/qBittorrent 0750 qbittorrent qbittorrent -"
  ];

  services.qbittorrent = {
    enable = true;
    openFirewall = false; # nginx fronts this
    webuiPort = services.qbit.port;
  };

  users.users.qbittorrent.extraGroups = ["media"];

  systemd.services.qbittorrent = {
    serviceConfig = {
      ReadWritePaths = ["/var/lib/media"];
      UMask = lib.mkForce "0002";
    };
  };
}
