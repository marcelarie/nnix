{pkgs, config, ...}: let
  logDir = "/var/log/bandcampsync";
  htmlDir = "/var/lib/bandcampsync-status";
  genReport = pkgs.writeShellScript "bandcampsync-report" ''
    set -e
    mkdir -p ${htmlDir}
    SINCE=$(systemctl show -p ExecMainStartTimestamp bandcampsync.service | cut -d= -f2-)
    EXIT=$(systemctl show -p ExecMainStatus bandcampsync.service | cut -d= -f2)
    journalctl -u bandcampsync.service -n 2000 --no-pager -o cat > /run/bcs.lastlog || true
    FLAC=$(grep -c 'Moving extracted file.*\.flac' /run/bcs.lastlog || true)
    AIFF=$(grep -c 'Moving extracted file.*\.aiff' /run/bcs.lastlog || true)
    ALBUMS=$(grep -oP 'Downloading item "\K[^"]+' /run/bcs.lastlog | sort -u || true)
    SKIP_PRE=$(grep -c 'preorder, skipping' /run/bcs.lastlog || true)
    AUTH=$([ "$EXIT" = "0" ] && echo OK || echo FAILED)
    {
      echo '<!doctype html><meta charset="utf-8"><title>bandcampsync</title>'
      echo '<style>body{font:14px system-ui;max-width:60em;margin:3em auto;padding:0 1em}'
      echo '.ok{color:green}.bad{color:red}li{margin:.2em 0}</style>'
      echo "<h1>bandcampsync — last run</h1>"
      echo "<p><b>Auth:</b> <span class=$([ "$AUTH" = OK ] && echo ok || echo bad)>$AUTH</span> "
      echo "(exit $EXIT)</p>"
      echo "<p><b>Started:</b> $SINCE</p>"
      echo "<p><b>Tracks synced:</b> flac $FLAC · aiff $AIFF "
      echo "· skipped preorders $SKIP_PRE</p>"
      echo "<h2>Albums</h2>"
      if [ -z "$ALBUMS" ]; then
        echo '<p class=ok>Collection up to date — nothing new to sync.</p>'
      fi
      echo '<ul>'
      echo "$ALBUMS" | while IFS= read -r a; do [ -n "$a" ] && echo "<li>$a</li>"; done
      echo '</ul>'
      echo '<p><a href="last.log">Full log</a></p>'
    } > ${htmlDir}/index.html
    cp /run/bcs.lastlog ${htmlDir}/last.log
  '';
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
    };
    path = [pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.systemd];
    script = toString genReport;
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
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
