{
  pkgs,
  lib,
  ...
}: {
  services.mediamtx = {
    enable = true;
    allowVideoAccess = true; # grants the "video" group so /dev/video0 is readable
    settings = {
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
        runOnInit = "${lib.getExe pkgs.ffmpeg} -f v4l2 -i /dev/video0 -f rtsp rtsp://localhost:$RTSP_PORT/$RTSP_PATH";
        runOnInitRestart = true;
      };
    };
  };
  networking.firewall.allowedUDPPorts = [8189];
}
