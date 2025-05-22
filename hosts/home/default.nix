{
  config,
  pkgs,
  pkgsStable,
  ...
}: {
  imports = [../../home/common.nix];
  home.username = "marcel";
  home.homeDirectory = "/home/marcel";

  home.packages = with pkgs; [
    stremio
    zeroad
    telegram-desktop
  ];
}
