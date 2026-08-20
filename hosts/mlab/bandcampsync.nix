{pkgs, ...}: let
  htmlDir = "/var/lib/bandcampsync-status";
  reportPy = ./bandcampsync_report.py;
in {
  # bandcamp cookies arrive via syncthing from laptop (see syncthing.nix)

  systemd.services.bandcampsync = {
    description = "Sync Bandcamp collection to music (flac) and dj (aiff)";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    path = [pkgs.bash pkgs.coreutils pkgs.python313Packages.pipx];
    onFailure = ["bandcampsync-report.service"];
    unitConfig.OnSuccess = "bandcampsync-report.service";
    script = ''
      set -e
      # filter to bandcamp-only cookies (full-profile exports break the tool)
      grep bandcamp /var/lib/syncthing/bandcamp-cookies/cookies.txt > /run/bandcamp_cookies_filtered.txt
      chmod 400 /run/bandcamp_cookies_filtered.txt
      # fetch real bandcamp album URLs (id -> item_url) from collection metadata
      pipx run --spec bandcampsync python3 ${reportPy} fetch-urls
      pipx run bandcampsync -c /run/bandcamp_cookies_filtered.txt -d /var/lib/media/music -f flac --skip-hidden
      pipx run bandcampsync -c /run/bandcamp_cookies_filtered.txt -d /var/lib/media/dj -f aiff-lossless --skip-hidden
      rm /run/bandcamp_cookies_filtered.txt
    '';
  };

  systemd.services.bandcampsync-report = {
    description = "Generate bandcampsync status html";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Environment = "PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo";
    };
    path = [pkgs.bash pkgs.python313 pkgs.systemd];
    script = "${pkgs.python313}/bin/python3 ${reportPy} generate";
  };

  # static status page at https://bcsync.marcel.cool (added to proxy.nix)
  services.nginx.virtualHosts."bcsync.marcel.cool" = {
    forceSSL = true;
    useACMEHost = "marcel.cool";
    root = htmlDir;
    extraConfig = "autoindex off;";
  };

  systemd.timers.bandcampsync = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = ["08:00" "16:00" "00:00"];
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
