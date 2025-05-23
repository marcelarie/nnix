{ config, pkgs, pkgsStable, ... }: {
  home.username = "marcel";
  home.homeDirectory = "/home/marcel";
  imports = [ ../../home/common.nix ];

  home.packages = with pkgs; [ hyprlock stremio zeroad telegram-desktop ];
}
