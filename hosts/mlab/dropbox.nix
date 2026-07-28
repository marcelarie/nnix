{...}: {
  users.groups.dropbox = {};

  users.users.share_guest = {
    isNormalUser = true;
    extraGroups = ["dropbox"];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICt4VE3AHMG49lg2uwTft1vIROkUYjID9SGIuofbABcv jufegam@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIX6VDkGBXjeZiiyX7v4HqAo69k2youKkCTC1M3lnPXc jufegam@gmail.com"
    ];
  };

  users.users.dev.extraGroups = ["dropbox"];
  systemd.tmpfiles.rules = [
    "d /home/share_guest 0750 share_guest dropbox -"
    "d /home/share_guest/dropbox 2770 share_guest dropbox -"
  ];
}
