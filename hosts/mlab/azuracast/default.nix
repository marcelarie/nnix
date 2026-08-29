{
  config,
  pkgs,
  services,
  ...
}: let
  # loopback-only; referenced by the "= /listen-time" nginx location in proxy.nix.
  # Kept OUT of the shared `services` attrset on purpose: that attrset feeds the firewall's
  # allowedTCPPorts, and this port must stay loopback-only.
  listenTimePort = 8320;
in {
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
  # public_custom_css / public_custom_js are loaded from standalone files (see ./azuracast-public.{css,js}).
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
      CSS_FILE=${./azuracast-public.css}
      JS_FILE=${./azuracast-public.js}

      for i in $(seq 1 60); do
        if podman exec azuracast azuracast_cli azuracast:settings:set homepage_redirect_url /public/radio_marcel 2>/dev/null; then
          echo "azuracast-settings: homepage_redirect_url=/public/radio_marcel"

          podman exec azuracast azuracast_cli azuracast:settings:set public_custom_css "$(cat "$CSS_FILE")" 2>/dev/null \
            && echo "azuracast-settings: public_custom_css (from $CSS_FILE)"

          podman exec azuracast azuracast_cli azuracast:settings:set public_custom_js "$(cat "$JS_FILE")" 2>/dev/null \
            && echo "azuracast-settings: public_custom_js (from $JS_FILE)"

          # HLS delivery. The plain mp3 mount is a single endless TCP connection, so any blip on
          # the listener's side kills it outright and nothing server-side can prevent that. HLS
          # ships the same audio as short segments the player fetches ahead and retries
          # individually, so a brief outage costs one segment instead of the whole stream.
          #
          # Both knobs live in the DB with no azuracast_cli setter: enable_hls is a station
          # column, and the actual output needs at least one row in station_hls_streams -
          # enable_hls on its own leaves liquidsoap with nothing to encode and the hls dir empty,
          # which nginx then serves as a 404 (its location does try_files $uri =404).
          #
          # Everything is guarded on current state and the radio is restarted at most once,
          # because azuracast:radio:restart disconnects every listener - unguarded, each
          # nixos-rebuild would drop the whole audience.
          mysql() { podman exec azuracast mariadb -N -B -u azuracast -p${config.virtualisation.oci-containers.containers.azuracast.environment.MYSQL_PASSWORD} azuracast -e "$1" 2>/dev/null; }

          SID=$(mysql "SELECT id FROM station WHERE short_name='radio_marcel';")
          HLS_CHANGED=0

          # avoid_duplicates makes the queue builder skip any track whose artist played
          # recently. With an album-shaped library that means it selects artist-uniformly
          # instead of track-uniformly: a 1-track artist got 18 plays in 3 days while each
          # track of a 13-track album got 2.6. It also wipes the shuffle cycle whenever
          # nothing passes the filter ("Duplicate prevention yielded no playable song;
          # resetting song queue"), so the library never finishes a full pass. Off = plain
          # shuffle, every track once per ~14h cycle.
          if [ "$(mysql "SELECT avoid_duplicates FROM station_playlists WHERE station_id=$SID AND name='default';")" = "1" ]; then
            mysql "UPDATE station_playlists SET avoid_duplicates=0 WHERE station_id=$SID AND name='default';" \
              && echo "azuracast-settings: avoid_duplicates=0"
          fi

          if [ "$(mysql "SELECT enable_hls FROM station WHERE id=$SID;")" = "0" ]; then
            if mysql "UPDATE station SET enable_hls=1 WHERE id=$SID;"; then
              HLS_CHANGED=1
              echo "azuracast-settings: enable_hls=1"
            fi
          fi

          if [ "$(mysql "SELECT COUNT(*) FROM station_hls_streams WHERE station_id=$SID;")" = "0" ]; then
            if mysql "INSERT INTO station_hls_streams (station_id, name, format, bitrate, listeners) VALUES ($SID, 'aac_192', 'aac', 192, 0);"; then
              HLS_CHANGED=1
              echo "azuracast-settings: added hls stream aac_192"
            fi
          fi

          if [ "$HLS_CHANGED" = "1" ]; then
            podman exec azuracast azuracast_cli azuracast:radio:restart radio_marcel 2>/dev/null \
              && echo "azuracast-settings: radio restarted for hls"
          else
            echo "azuracast-settings: hls already configured, leaving radio alone"
          fi

          exit 0
        fi
        sleep 5
      done
      echo "azuracast-settings: gave up; last error:" >&2
      podman exec azuracast azuracast_cli azuracast:settings:set homepage_redirect_url /public/radio_marcel >&2
      exit 1
    '';
  };

  # Auto-add every file under /var/lib/media/music to the default rotation.
  # AzuraCast imports new files into station_media within ~1 min but never adds
  # them to a playlist, so they sit imported-but-unplayed. The native 5-min
  # CheckFolderPlaylistsTask links folder-matched media into a playlist and
  # prunes stale rows - but it matches `sm.path LIKE path.'/%'` and
  # station_media.path is relative with no leading slash, so NO folder path
  # matches the library root; only one row per top-level subfolder works. This
  # just ensures those rows exist idempotently (no unique key on
  # station_playlist_folders, hence NOT EXISTS); the native task does the actual
  # linking and dedupes via addMediaToPlaylist for shuffle playlists, so the
  # 138 manually-linked tracks get adopted, not doubled. New artists dropped in
  # by bandcampsync join rotation within ~10 min - no per-sync glue needed in
  # bandcampsync.nix.
  systemd.services.azuracast-autoplaylist = {
    description = "Link default AzuraCast playlist to every top-level media folder";
    after = ["podman-azuracast.service"];
    path = [pkgs.podman pkgs.coreutils];
    serviceConfig.Type = "oneshot";
    script = ''
      mysql() { podman exec azuracast mariadb -N -B -u azuracast -p${config.virtualisation.oci-containers.containers.azuracast.environment.MYSQL_PASSWORD} azuracast -e "$1" 2>/dev/null; }

      SID=$(mysql "SELECT id FROM station WHERE short_name='radio_marcel';")
      PID=$(mysql "SELECT id FROM station_playlists WHERE station_id=$SID AND name='default' AND source='songs' LIMIT 1;")
      [ -n "$SID" ] && [ -n "$PID" ] || { echo "azuracast-autoplaylist: station/playlist not ready"; exit 0; }

      # quote-doubling (MariaDB single-quoted string escape) for apostrophes in folder names
      q="'"
      find /var/lib/media/music -maxdepth 1 -mindepth 1 -type d ! -name '.*' -printf '%f\n' 2>/dev/null \
        | while IFS= read -r dir; do
            esc=$(printf '%s' "$dir" | sed "s/$q/$q$q/g")
            mysql "INSERT INTO station_playlist_folders (station_id, playlist_id, path) SELECT $SID, $PID, '$esc' FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM station_playlist_folders WHERE station_id=$SID AND playlist_id=$PID AND path='$esc');"
          done
      echo "azuracast-autoplaylist: ensured folder rows for station=$SID playlist=$PID"
    '';
  };

  systemd.timers.azuracast-autoplaylist = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
      AccuracySec = "30s";
      RandomizedDelaySec = "1m";
    };
  };

  # Per-IP listen-time endpoint for the public radio page. The public AzuraCast API only exposes
  # aggregate listener counts; the per-IP numbers live in the DB `listener` table, so this small
  # service reads them via podman exec (same pattern as azuracast-settings/autoplaylist) and
  # serves GET /listen-time on 127.0.0.1. Nginx fronts it as same-origin /listen-time
  # (proxy.nix) with X-Real-IP/X-Forwarded-For = the client, so each visitor only ever gets back
  # their own aggregate.
  systemd.services.azuracast-listen-time = {
    description = "Per-IP listen-time endpoint for the radio public page";
    after = ["network.target" "podman-azuracast.service"];
    wants = ["podman-azuracast.service"];
    wantedBy = ["multi-user.target"];
    path = [pkgs.podman];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.python3}/bin/python3 ${./azuracast-listen-time.py} ${toString listenTimePort}";
      Environment = [
        "MYSQL_PASSWORD=${config.virtualisation.oci-containers.containers.azuracast.environment.MYSQL_PASSWORD}"
      ];
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
