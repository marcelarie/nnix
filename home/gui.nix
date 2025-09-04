{
  config,
  pkgs,
  inputs,
  pkgsStable,
  ...
}: let
  homeDir = config.home.homeDirectory;
  pstore = "${homeDir}/clones/own/password-store";
in {
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    OPENSSL_DIR = "${pkgs.openssl.out}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = ["nvim-terminal.desktop"];
      "text/markdown" = ["nvim-terminal.desktop"];
      "text/html" = ["nvim-terminal.desktop"];
      "application/json" = ["nvim-terminal.desktop"];
      
      # Web browser scheme handlers
      "x-scheme-handler/http" = ["firefox_firefox.desktop"];
      "x-scheme-handler/https" = ["firefox_firefox.desktop"];
      "x-scheme-handler/about" = ["firefox_firefox.desktop"];
      "x-scheme-handler/unknown" = ["firefox_firefox.desktop"];

      "image/png" = ["imv.desktop"];
      "image/jpeg" = ["imv.desktop"];
      "image/jpg" = ["imv.desktop"];
      "image/gif" = ["imv.desktop"];
      "image/webp" = ["imv.desktop"];
      "image/tiff" = ["imv.desktop"];
      "image/bmp" = ["imv.desktop"];
      "image/svg+xml" = ["imv.desktop"];
      "image/avif" = ["imv.desktop"];
      "image/heif" = ["imv.desktop"];
      "image/heic" = ["imv.desktop"];

      "application/pdf" = ["zathura.desktop" "org.pwmt.zathura-pdf-mupdf.desktop"];
    };
    associations = {
      added = {
        "text/plain" = ["nvim-terminal.desktop"];
        "text/markdown" = ["nvim-terminal.desktop"];
        "text/json" = ["nvim-terminal.desktop"];
        "application/json" = ["nvim-terminal.desktop"];

        "image/png" = ["imv.desktop"];
        "image/jpeg" = ["imv.desktop"];
        "image/jpg" = ["imv.desktop"];
        "image/gif" = ["imv.desktop"];
        "image/webp" = ["imv.desktop"];
        "image/tiff" = ["imv.desktop"];
        "image/bmp" = ["imv.desktop"];
        "image/svg+xml" = ["imv.desktop"];
        "image/avif" = ["imv.desktop"];
        "image/heif" = ["imv.desktop"];
        "image/heic" = ["imv.desktop"];

        "application/pdf" = ["org.pwmt.zathura-pdf-mupdf.desktop"];
      };
      removed = {
        "image/png" = ["gimp.desktop" "chromium-browser.desktop"];
        "image/jpeg" = ["gimp.desktop"];
        "image/jpg" = ["gimp.desktop"];
        "image/gif" = ["gimp.desktop"];
        "image/webp" = ["gimp.desktop"];
        "image/tiff" = ["gimp.desktop"];
        "image/bmp" = ["gimp.desktop"];
        "image/svg+xml" = ["gimp.desktop"];
        "image/avif" = ["gimp.desktop"];
        "image/heif" = ["gimp.desktop"];
        "image/heic" = ["gimp.desktop"];
      };
    };
  };

  home.packages = with pkgs; [
    blesh
    abiword
    blueman
    brightnessctl
    cliphist
    dejavu_fonts
    dmenu-wayland
    eww
    fira-sans
    font-awesome
    foot
    gimp3
    grimblast
    hyprpaper
    hyprshot
    kanshi
    keyd
    batsignal
    liberation_ttf
    mako
    nerd-fonts.blex-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.iosevka-term
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-extra
    nwg-look
    pamixer
    pavucontrol
    pyprland
    qbittorrent
    roboto
    roboto-mono
    roboto-serif
    rustdesk
    satty
    swayimg
    swayosd
    telegram-desktop
    tofi
    ubuntu-sans-mono
    way-displays
    waybar
    wf-recorder
    wl-clipboard
    wlr-layout-ui
    wofi-emoji
    ydotool
    zathura
    penguin-subtitle-player
    unzip
    flameshot
    swappy
    ironbar
    distrobox
  ];

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
  in {
    # GUI-specific config files only
    ".config/hypr/hyprland.conf".source =
      link "${dots}/.config/hypr/hyprland.conf";
    ".config/hypr/hypridle.conf".source =
      link "${dots}/.config/hypr/hypridle.conf";
    ".config/hypr/hyprlock.conf".source =
      link "${dots}/.config/hypr/hyprlock.conf";
    ".config/hypr/hyprpaper.conf".source =
      link "${dots}/.config/hypr/hyprpaper.conf";
    ".config/hypr/keybinds.conf".source =
      link "${dots}/.config/hypr/keybinds.conf";
    ".config/hypr/monitors.conf".source =
      link "${dots}/.config/hypr/monitors.conf";
    ".config/hypr/pyprland.toml".source =
      link "${dots}/.config/hypr/pyprland.toml";
    ".config/hypr/workspaces.conf".source =
      link "${dots}/.config/hypr/workspaces.conf";
    ".config/foot/foot.ini".source = link "${dots}/.config/foot/foot.ini";
    ".config/tofi/config".source = link "${dots}/.config/tofi/config";
    ".config/mako/config".source = link "${dots}/.config/mako/config";
    ".config/ironbar/config.toml".source = link "${dots}/.config/ironbar/config.toml";

    # GUI-specific directories
    ".config/waybar" = {
      source = link "${dots}/.config/waybar";
      recursive = true;
    };

    ".config/eww" = {
      source = link "${dots}/.config/eww";
      recursive = true;
    };
  };
}
