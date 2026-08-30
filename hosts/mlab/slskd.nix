{
  config,
  lib,
  services,
  ...
}: {
  sops.secrets."slsk_pass" = {};
  sops.secrets."slsk_user" = {};
  sops.secrets."slskd_api_key" = {};

  sops.templates."slskd-mlab.env" = {
    content = ''
      APP_DIR=/var/lib/slskd

      SLSKD_SLSK_USERNAME='${config.sops.placeholder.slsk_user}'
      SLSKD_SLSK_PASSWORD='${config.sops.placeholder.slsk_pass}'

      SLSKD_USERNAME='${config.sops.placeholder.web_user}'
      SLSKD_PASSWORD='${config.sops.placeholder.web_pass}'

      SLSKD_WEB_USERNAME=${config.sops.placeholder.web_user}
      SLSKD_WEB_PASSWORD=${config.sops.placeholder.web_pass}
    '';
    owner = "slskd";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/slskd 0755 slskd slskd -"
    "d /var/lib/slskd/music 0755 slskd slskd -"
    "d /var/lib/slskd/music/downloads 0755 slskd slskd -"
    "d /var/lib/slskd/music/incompleted 0755 slskd slskd -"
    "d /etc/slskd 0755 slskd slskd -"
    "d /var/lib/slskd/music/share 0775 slskd media -"
  ];

  # Disabled. Before re-enabling, supply the API key via the `slskd_api_key` sops
  # secret and environmentFile - `settings` lands world-readable in the nix store.
  services.slskd = {
    enable = false;
    openFirewall = false;
    domain = null;
    user = "slskd";
    group = "slskd";
    environmentFile = config.sops.templates."slskd-mlab.env".path;
    settings = {
      directories = {
        downloads = "/var/lib/slskd/music/downloads";
        incomplete = "/var/lib/slskd/music/incompleted";
      };
      shares = {
        directories = ["/var/lib/slskd/music/share"];
      };
      soulseek = {
        listen_port = 50300;
      };
      web = {
        port = services.slskd.port;
        address = "127.0.0.1"; # nginx fronts the web UI
      };
      global = {
        upload.slots = 10;
        download.slots = 10;
      };
    };
  };

  users.users.slskd = {
    isSystemUser = true;
    group = "slskd";
    home = "/var/lib/slskd";
    createHome = true;
  };
  users.groups.slskd = {};

  systemd.services.slskd.serviceConfig = {
    Restart = lib.mkForce "always";
    RestartSec = "5s";
    StateDirectory = "slskd";
    WorkingDirectory = "/var/lib/slskd";
    UMask = "0022";
  };
}
