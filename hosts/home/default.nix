{ config, pkgs, pkgsStable, ... }: {
  home.username = "marcel";
  home.homeDirectory = "/home/marcel";
  imports = [ ../../home/common.nix ];

  home.packages = with pkgs; [
    hyprlock
    hyprland-qtutils
    stremio
    zeroad
    telegram-desktop
    ungoogled-chromium
    firefox
  ];
}
