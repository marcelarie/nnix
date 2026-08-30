{
  config,
  pkgs,
  services,
  ...
}: let
  # Piper voices are plain data files on huggingface; fetching them at build time keeps the
  # unit stateless (no first-run download, no StateDirectory, no network dep at runtime).
  voiceBase = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/amy/medium";
  voiceOnnx = pkgs.fetchurl {
    url = "${voiceBase}/en_US-amy-medium.onnx";
    hash = "sha256-s6bke1e4x/vmoM4lGBYaUPWanN2KUINcAssCvdYgbBg=";
  };
  voiceJson = pkgs.fetchurl {
    url = "${voiceBase}/en_US-amy-medium.onnx.json";
    hash = "sha256-laI+tNQpCdON9zu5rH9F9Zfb/N4tG/lSb96vVGaXfXc=";
  };
in {
  sops.secrets."azuracast_api_key" = {
    owner = "dev";
    mode = "0400";
  };

  sops.templates."radio-bot.env" = {
    content = ''
      MINIFLUX_API_KEY=${config.sops.placeholder.miniflux_api}
      SYNTHETIC_API_KEY=${config.sops.placeholder.synthetic_api_key}
      AZURACAST_API_KEY=${config.sops.placeholder.azuracast_api_key}
    '';
    owner = "dev";
    mode = "0400";
  };

  systemd.services.azuracast-radio-bot = {
    description = "Generate and upload AI radio news bulletin";
    wants = ["network-online.target"];
    after = ["network-online.target" "miniflux.service" "podman-azuracast.service"];
    path = [pkgs.piper-tts];
    serviceConfig = {
      Type = "oneshot";
      User = "dev";
      EnvironmentFile = config.sops.templates."radio-bot.env".path;
      Environment = [
        "MINIFLUX_URL=http://127.0.0.1:${toString services.miniflux.port}"
        "AZURACAST_URL=http://127.0.0.1:${toString services.azuracast.port}"
        "PIPER_MODEL=${voiceOnnx}"
        "PIPER_CONFIG=${voiceJson}"
        "TZ=${config.time.timeZone}"
        "PYTHONTZPATH=${pkgs.tzdata}/share/zoneinfo"
      ];
      ExecStart = "${pkgs.python3.withPackages (p: [p.requests])}/bin/python3 ${./radio-bot.py}";
    };
  };

  systemd.timers.azuracast-radio-bot = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = ["07:30" "16:30"];
      Persistent = true;
    };
  };
}
