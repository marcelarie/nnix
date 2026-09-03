{
  config,
  pkgs,
  services,
  ...
}: {
  sops.secrets."azuracast_dj_password" = {};

  # Captures the Scarlett 2i2 and pushes it into AzuraCast's DJ harbor (127.0.0.1:8005,
  # published from the container in ./default.nix). Not started at boot: an idle mixer would
  # push dead air over the auto-DJ. Toggle via https://livedj.marcel.cool or systemctl.
  systemd.services.azuracast-live-capture = {
    description = "Capture Scarlett 2i2 input and stream it live to AzuraCast";
    after = ["sound.target" "podman-azuracast.service"];
    serviceConfig = {
      Type = "simple";
      RuntimeDirectory = "azuracast-live-capture";
      RuntimeDirectoryMode = "0700";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    # darkice's config is a plain file, so it's generated at start into RuntimeDirectory
    # (tmpfs, root-only) with the password read from sops at runtime - never written to the
    # nix store. plughw (not hw): the Scarlett 2i2 needs ALSA's plugin layer for format
    # conversion. mountPoint is blank: darkice always sends "SOURCE /" + mountPoint, so "/"
    # would send "SOURCE //", which doesn't match AzuraCast's DJ mount point ("/").
    script = ''
      DJ_PASSWORD=$(cat ${config.sops.secrets.azuracast_dj_password.path})
      cat > /run/azuracast-live-capture/darkice.cfg <<EOF
      [general]
      duration = 0
      bufferSecs = 5
      reconnect = yes

      [input]
      device = plughw:CARD=USB
      sampleRate = 44100
      bitsPerSample = 16
      channel = 2

      [icecast2-0]
      bitrateMode = cbr
      format = mp3
      bitrate = 192
      server = 127.0.0.1
      port = 8005
      password = $DJ_PASSWORD
      mountPoint =
      name = Live DJ
      public = no
      EOF
      exec ${pkgs.darkice}/bin/darkice -c /run/azuracast-live-capture/darkice.cfg
    '';
  };

  # Tiny status/start-stop page for the capture service above, sat behind Authelia via
  # the `livedj` entry in proxy.nix's `services` set. Runs unprivileged; the only thing
  # it can do as root is start/stop this one unit (security.sudo.extraRules below).
  users.users.azuracast-live-web = {
    isSystemUser = true;
    group = "azuracast-live-web";
  };
  users.groups.azuracast-live-web = {};

  systemd.services.azuracast-live-web = {
    description = "Toggle page for the live DJ capture stream";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      User = "azuracast-live-web";
      ExecStart = "${pkgs.python3}/bin/python3 ${./live-toggle.py} ${toString services.livedj.port}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  security.sudo.extraRules = [
    {
      users = ["azuracast-live-web"];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start azuracast-live-capture";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/systemctl stop azuracast-live-capture";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
