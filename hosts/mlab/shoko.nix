{
  _config,
  pkgs,
  lib,
  ...
}: let
  avdump3-net8 = pkgs.runCommand "avdump3-net8" {} ''
    mkdir -p $out/share
    cp -r ${pkgs.avdump3}/share/avdump3 $out/share/avdump3
    chmod -R u+w $out
    sed -i 's/6\.0/8.0/g' $out/share/avdump3/AVDump3CL.runtimeconfig.json
  '';
in {
  services.shoko = {
    enable = true;
    openFirewall = true;
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/media/anime 2775 root media -"
    "d /var/lib/media/downloads/anime 2775 root media -"
  ];

  systemd.services.shoko = {
    path = [pkgs.dotnet-runtime];
    preStart = ''
      rm -rf /var/lib/shoko/AVDump
      ln -sfn ${avdump3-net8}/share/avdump3 /var/lib/shoko/AVDump
    '';

    serviceConfig = {
      SupplementaryGroups = ["media"];
      ReadWritePaths = ["/var/lib/media"];
      UMask = lib.mkForce "0002";
    };
  };
}
