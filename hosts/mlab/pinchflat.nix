{
  lib,
  services,
  ...
}: {
  services.pinchflat = {
    enable = true;
    openFirewall = true;
    port = services.pinchflat.port;
    mediaDir = "/var/lib/media/youtube";
    selfhosted = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/media/youtube 2775 root media -"
  ];

  users.users.pinchflat.extraGroups = ["media"];

  systemd.services.pinchflat.serviceConfig = {
    ReadWritePaths = ["/var/lib/media"];
    UMask = lib.mkForce "0002";
  };
}
