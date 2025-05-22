{
  config,
  pkgs,
  pkgsStable,
  ...
}: {
  home.username = "marcel";
  home.homeDirectory = "/home/marcel";
  imports = [../../home/common.nix];

  home.packages = with pkgs; [
    stremio
    zeroad
    telegram-desktop
  ];
}
