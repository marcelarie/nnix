{
  config,
  pkgs,
  pkgsStable,
  nixGL,
  ...
}: let
  homeDir = "/home/marcel";
in {
  home.username = "marcel";
  home.homeDirectory = homeDir;
  imports = [
    ../../home/terminal.nix
    ../../home/gui.nix
  ];

  # nixGL = {
  #   packages = nixGL.packages;
  #   defaultWrapper = "mesa";
  # };

  home.packages = with pkgs; [
    (config.lib.nixGL.wrap mixxx)
    pkgsStable.hyprlock
    pkgsStable.hyprland-qtutils
    # stremio
    alacritty
    neovide
    xdg-desktop-portal-hyprland
    grim
    # zeroad
    slurp
    telegram-desktop
    # ungoogled-chromium
    firefox
    imv
    alsa-utils
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    (pkgs.writeShellScriptBin "vivaldi-stable" ''
      exec -a "$0" ${pkgs.vivaldi}/bin/vivaldi-stable --ozone-platform-hint=wayland --enable-features=WaylandWindowDecorations "$@"
    '')
  ];

  programs.mpv = {
    enable = true;
    scripts = [pkgs.mpvScripts.mpris];
  };

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
  in {
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config";
    ".config/hypr/devices/nixos.conf".source = link "${dots}/.config/hypr/devices/nixos.conf";
  };
}
