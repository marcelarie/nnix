{
  config,
  lib,
  services,
  ...
}: {
  # NOTE: qBittorrent's live config is /var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
  # (the service runs with --profile=/var/lib/qBittorrent). It is NOT managed by nix: the
  # module's profile path doesn't match /var/lib/qbittorrent/.config/... where a sops template
  # used to be copied, so that file was never read (and its key names were wrong — e.g.
  # `LocalHostAuth=false` would have ENABLED the localhost auth bypass, which an attacker
  # abused on 2026-08-30 to inject a torrent-add AutoRun payload; it's now disabled in the
  # live file). Editing settings: qbit WebUI, they persist on exit.

  systemd.tmpfiles.rules = [
    "d /var/lib/qbittorrent 0775 qbittorrent media -"
    "d /var/lib/qbittorrent/.config/qBittorrent 0750 qbittorrent qbittorrent -"
  ];

  services.qbittorrent = {
    enable = true;
    openFirewall = true;
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
