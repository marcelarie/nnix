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
      # WebRTC only - rtsp stays on (internal-only, used by the ffmpeg push below) but hls/rtmp
      # are unused here. hls's default port (8888) collided with an existing podman container on
      # this host, so it's off rather than picking a new port for a server nothing reads from.
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
        # -an: video only, explicitly - the webcam's mic (if any) is a separate ALSA device,
        # never captured by -f v4l2 in the first place, but this keeps that guaranteed even if
        # the command changes later.
        # -c:v libx264 is required, not cosmetic: ffmpeg's RTSP default (no -c:v given) picked
        # old MPEG-4 Part 2, which WebRTC's codec list (H264/H265/VP8/VP9/AV1) doesn't include at
        # all - MediaMTX rejected every WebRTC session with "no supported codec" even though the
        # capture itself was working. ultrafast/zerolatency trade quality for encoding speed,
        # since this needs to keep up with the camera in real time, not archive it.
        runOnInit = "${lib.getExe pkgs.ffmpeg} -f v4l2 -i /dev/video0 -an -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -f rtsp rtsp://localhost:$RTSP_PORT/$RTSP_PATH";
        runOnInitRestart = true;
      };
    };
  };
  networking.firewall.allowedUDPPorts = [8189];

  # services.mediamtx always writes its config via pkgs.formats.yaml, which prepends a
  # "%YAML 1.1\n---\n" document header - MediaMTX's own YAML parser rejects that header outright
  # ("ERR: invalid YAML", confirmed by hand against the actual binary), even though the rest of
  # the generated file is fine. Strip just those first two lines.
  environment.etc."mediamtx.yaml".source = lib.mkForce (
    pkgs.runCommand "mediamtx.yaml" {} ''
      tail -n +3 ${(pkgs.formats.yaml {}).generate "mediamtx.yaml" config.services.mediamtx.settings} > $out
    ''
  );

  # Private preview + "go live" switch: Station admin (Authelia-gated, see proxy.nix/authelia.nix)
  # can watch the same WHEP stream the public page would use, then flip a flag that the public
  # page checks (radio.marcel.cool/webcam-status, unauthenticated, see proxy.nix) before it ever
  # shows the video element - so testing the feed never exposes it on the public page.
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
