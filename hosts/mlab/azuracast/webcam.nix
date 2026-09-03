{
  config,
  pkgs,
  lib,
  services,
  ...
}: {
  services.mediamtx = {
    enable = true;
    allowVideoAccess = true; # grants the "video" group so /dev/video0 is readable
    settings = {
      # WebRTC only - rtsp stays on (internal-only, used by the ffmpeg push below); hls/rtmp are
      # unused and hls's default port collides with an existing container on this host.
      hls = false;
      rtmp = false;
      webrtcAdditionalHosts = ["radio.marcel.cool"];
      webrtcAddress = "127.0.0.1:8889";
      authInternalUsers = [
        {
          user = "any";
          ips = ["127.0.0.1" "::1"];
          permissions = [
            {action = "publish";}
            {action = "read";}
          ];
        }
        {
          user = "any";
          ips = [];
          permissions = [
            {action = "read";}
          ];
        }
      ];

      paths.webcam = {
        # -c:v libx264 is required, not cosmetic: ffmpeg's RTSP default encoder is MPEG-4 Part 2,
        # which isn't in WebRTC's codec list (H264/H265/VP8/VP9/AV1). ultrafast/zerolatency keep
        # the encoder fast enough for real-time capture.
        runOnInit = "${lib.getExe pkgs.ffmpeg} -f v4l2 -i /dev/video0 -an -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -f rtsp rtsp://localhost:$RTSP_PORT/$RTSP_PATH";
        runOnInitRestart = true;
      };
    };
  };
  networking.firewall.allowedUDPPorts = [8189];

  # services.mediamtx writes its config via pkgs.formats.yaml, which prepends a
  # "%YAML 1.1\n---\n" header that MediaMTX's own parser rejects. Strip those first two lines.
  environment.etc."mediamtx.yaml".source = lib.mkForce (
    pkgs.runCommand "mediamtx.yaml" {} ''
      tail -n +3 ${(pkgs.formats.yaml {}).generate "mediamtx.yaml" config.services.mediamtx.settings} > $out
    ''
  );

  # Private preview + "go live" switch (Authelia-gated, see proxy.nix/authelia.nix). The public
  # page polls radio.marcel.cool/webcam-status before ever showing the video element.
  users.users.webcam-control = {
    isSystemUser = true;
    group = "webcam-control";
  };
  users.groups.webcam-control = {};

  systemd.services.webcam-control-web = {
    description = "Webcam preview + public-visibility toggle";
    after = ["network.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      User = "webcam-control";
      StateDirectory = "webcam-control";
      ExecStart = "${pkgs.python3}/bin/python3 ${./webcam-control.py} ${toString services.streamcam.port} /var/lib/webcam-control/live";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
