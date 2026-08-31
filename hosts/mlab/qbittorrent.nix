{
  config,
  lib,
  services,
  ...
}: {
  # The live config is /var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
  # (the service runs with --profile=/var/lib/qBittorrent). qBittorrent rewrites
  # the whole file on exit, so it can't be nix-managed wholesale - but the WebUI
  # password IS declarative: preStart injects the sops salt+hash into the conf
  # while the service is down. Other settings: edit in the WebUI, they persist.
  # Rotate: ~/scripts/qbit-pass.sh 'newpass' -> paste into secrets/mlab.yaml -> make mlab

  sops.secrets."qbit_password_salt" = {
    owner = "qbittorrent";
    restartUnits = ["qbittorrent.service"];
  };
  sops.secrets."qbit_password_hash" = {
    owner = "qbittorrent";
    restartUnits = ["qbittorrent.service"];
  };

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
    preStart = ''
      conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
      # runs as the qbittorrent user, which owns the conf; '.' matches the backslash
      if [ -f "$conf" ] && grep -q "^WebUI.Password_PBKDF2=" "$conf"; then
        sed -i "s|^\(WebUI.Password_PBKDF2=\).*|\1\"@ByteArray($(cat ${config.sops.secrets."qbit_password_salt".path}):$(cat ${config.sops.secrets."qbit_password_hash".path}))\"|" "$conf"
      else
        echo "qbittorrent preStart: $conf or its Password_PBKDF2 line missing; start once to create it" >&2
      fi
      # trust the local nginx proxy so bans/real IPs work; without this qbit bans
      # 127.0.0.1 after failed logins = whole world locked out for BanDuration
      grep -q "^WebUI.ReverseProxySupportEnabled=" "$conf" || \
        sed -i "/^\[Preferences\]/a WebUI\\\\ReverseProxySupportEnabled=true" "$conf"
      grep -q "^WebUI.TrustedReverseProxiesList=" "$conf" || \
        sed -i "/^\[Preferences\]/a WebUI\\\\TrustedReverseProxiesList=127.0.0.1" "$conf"
    '';
  };
}
