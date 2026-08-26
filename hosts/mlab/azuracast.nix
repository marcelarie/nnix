{
  config,
  pkgs,
  services,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d /var/lib/azuracast 0755 1000 1000 -"
    "d /var/lib/azuracast/stations 0755 1000 1000 -"
    "d /var/lib/azuracast/backups 0755 1000 1000 -"
    "d /var/lib/azuracast/mysql 0755 1000 1000 -"
    "d /var/lib/azuracast/storage 0755 1000 1000 -"
  ];

  virtualisation.oci-containers.containers.azuracast = {
    image = "ghcr.io/azuracast/azuracast:latest";
    environment = {
      APPLICATION_ENV = "production";
      TZ = config.time.timeZone;
      # mariadb is internal to the container (port not published)
      MYSQL_PASSWORD = "azur4c457";
      MYSQL_RANDOM_ROOT_PASSWORD = "yes";
    };
    volumes = [
      "/var/lib/azuracast/stations:/var/azuracast/stations"
      "/var/lib/azuracast/backups:/var/azuracast/backups"
      "/var/lib/azuracast/mysql:/var/lib/mysql"
      "/var/lib/azuracast/storage:/var/azuracast/storage"
      "/var/lib/media/music:/var/azuracast/media/music"
    ];
    ports = ["${toString services.azuracast.port}:80"];
    extraOptions = [
      "--group-add=986"
    ];
  };

  # declarative azuracast settings, applied via the app's own cli so they survive fresh installs and resist ui drift.
  systemd.services.azuracast-settings = {
    description = "Apply declarative AzuraCast settings";
    after = ["podman-azuracast.service"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for i in $(seq 1 60); do
        if podman exec azuracast azuracast_cli azuracast:settings:set homepage_redirect_url /public/radio_marcel 2>/dev/null; then
          echo "azuracast-settings: homepage_redirect_url=/public/radio_marcel"
          exit 0
        fi
        sleep 5
      done
      echo "azuracast-settings: gave up; last error:" >&2
      podman exec azuracast azuracast_cli azuracast:settings:set homepage_redirect_url /public/radio_marcel >&2
      exit 1
    '';
  };
}
