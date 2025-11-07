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
  imports = [
    ../../home/terminal.nix
    ../../home/gui.nix
  ];

  home.packages = with pkgs; [
    hyprlock
    hyprland-qtutils
    # stremio
    xdg-desktop-portal-hyprland
    grim
    zeroad
    slurp
    telegram-desktop
    ungoogled-chromium
    imv
    alsa-utils
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
  };
}
