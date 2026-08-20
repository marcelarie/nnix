{pkgs, config, ...}: let
  logDir = "/var/log/bandcampsync";
  htmlDir = "/var/lib/bandcampsync-status";
  genReport = pkgs.writeShellScript "bandcampsync-report" ''
    mkdir -p ${htmlDir}
    SINCE=$(systemctl show -p ExecMainStartTimestamp bandcampsync.service | cut -d= -f2-)
    EXIT=$(systemctl show -p ExecMainStatus bandcampsync.service | cut -d= -f2)
    journalctl -u bandcampsync.service --since "$SINCE" --no-pager -o cat > /run/bcs.lastlog || true
    FLAC=$(grep -c 'Moving extracted file.*\.flac' /run/bcs.lastlog || true)
    AIFF=$(grep -c 'Moving extracted file.*\.aiff' /run/bcs.lastlog || true)
    SKIP_PRE=$(grep -c 'preorder, skipping' /run/bcs.lastlog || true)
    ERRORS=$(grep -E '\[ERROR\]|\[WARNING\]' /run/bcs.lastlog | grep -v 'No valid notify target set' | grep -cv '^$' || true)
    AUTH=$([ "$EXIT" = "0" ] && echo OK || echo FAILED)
    # filesystem is source of truth: every downloaded album has bandcamp_item_id.txt
    T=$(mktemp); M=$(mktemp)
    scan(){ find /var/lib/media/$1 -mindepth 3 -maxdepth 3 -name bandcamp_item_id.txt 2>/dev/null | while read -r idf; do
      id=$(cat "$idf"); al=$(basename "$(dirname "$idf")"); ar=$(basename "$(dirname "$(dirname "$idf")")")
      echo "$id|$ar|$al|$2|$(stat -c %Y "$idf")" >> "$T"
    done; }
    scan music flac; scan dj aiff
    sort -t'|' -k1,1 "$T" | awk -F'|' '
      { if(!s[$1]){s[$1]=1;a[$1]=$2;b[$1]=$3;f[$1]=$4;m[$1]=$5}
        else{f[$1]=f[$1]","$4; if($5<m[$1])m[$1]=$5} }
      END{for(i in s)print i"|"a[i]"|"b[i]"|"f[i]"|"m[i]}' | sort -t'|' -k5,5rn > "$M"
    # pending = queued this run (will-download) minus completed (Writing id)
    grep 'New media item, will download' /run/bcs.lastlog 2>/dev/null \
      | sed -E 's/.*will download: "([^"]+)" \(id:([0-9]+)\).*/\2|\1/' | sort -u > "$T.will"
    grep 'Writing bandcamp item id' /run/bcs.lastlog 2>/dev/null \
      | sed -E 's/.*id:([0-9]+).*/\1/' | sort -u > "$T.done"
    esc(){ sed 's/&/\&amp;/g;s/</\&lt;/g;s/>/\&gt;/g'; }
    {
      echo '<!doctype html><meta charset="utf-8"><meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate"><title>bandcampsync</title>'
      echo '<style>body{font:14px system-ui;max-width:70em;margin:3em auto;padding:0 1em}'
      echo 'table{border-collapse:collapse;width:100%}td,th{border:1px solid #ccc;padding:4px 8px;text-align:left}'
      echo '.ok{color:green}.pend{color:darkorange}.fail{color:red}</style>'
      echo "<h1>bandcampsync</h1>"
      echo "<p><b>Auth:</b> <span class=$([ "$AUTH" = OK ] && echo ok || echo fail)>$AUTH</span> (exit $EXIT)"
      echo " · <b>Last run:</b> $(TZ=Europe/Madrid date -d "$SINCE" '+%Y-%m-%d %H:%M %Z')"
      echo " · <b>Tracks:</b> flac $FLAC aiff $AIFF · skipped preorders $SKIP_PRE"
      [ "$ERRORS" -gt 0 ] && echo " · <span class=fail>⚠ $ERRORS errors/warnings</span>"
      echo "</p>"
      echo "<h2>All albums</h2>"
      echo '<table><tr><th>Artist / Album</th><th>Status</th><th>Added</th><th>Format(s)</th></tr>'
      while IFS='|' read -r id ar al f e; do
        d=$(TZ=Europe/Madrid date -d @"$e" '+%Y-%m-%d %H:%M')
        echo "<tr><td>$(echo "$ar / $al" | esc)</td><td class=ok>✅ synced</td><td>$d</td><td>$f</td></tr>"
      done < "$M"
      comm -23 <(cut -d'|' -f1 "$T.will" | sort -u) "$T.done" | while read -r pid; do
        echo "<tr><td>$(grep "^$pid|" "$T.will" | cut -d'|' -f2- | esc)</td><td class=pend>⏳ pending</td><td>—</td><td>—</td></tr>"
      done
      echo '</table>'
      echo '<p><a href="last.log">Full log</a></p>'
    } > ${htmlDir}/index.html
    rm -f "$T" "$M" "$T.will" "$T.done"
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
    path = [pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnused pkgs.gnugrep pkgs.gawk pkgs.systemd];
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
      OnCalendar = ["08:00" "16:00" "00:00"];
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };
}
