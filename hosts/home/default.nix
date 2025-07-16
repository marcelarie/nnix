{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  homeDir = "/home/marcel";
in {
  home.username = "marcel";
  home.homeDirectory = homeDir;
  imports = [../../home/common.nix];

  home.packages = with pkgs; [
    hyprlock
    hyprland-qtutils
    stremio
    zeroad
    telegram-desktop
    ungoogled-chromium
    firefox
    imv
  ];

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
  in {
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config";
  };
}
