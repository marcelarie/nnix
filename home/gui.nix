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
  # imports = [inputs.zen-browser.homeModules.twilight];

  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  programs.firefox = {
    enable = true;

    profiles.default = {
      path = "08wgv37i.default-1759997538874";
      isDefault = true;
      userChrome = ''
#TabsToolbar,
#toolbar-menubar,
#PersonalToolbar,
#titlebar {
  visibility: collapse !important;
}

#navigator-toolbox {
  position: relative;
}

#nav-bar {
  margin-top: -40px !important;
  opacity: 0;
  z-index: 1;
  transition:
    margin-top 0.2s ease,
    opacity 0.2s ease !important;
}

#navigator-toolbox:focus-within #nav-bar {
  margin-top: 0 !important;
  opacity: 1 !important;
}
      '';
    };
  };

  # programs.zen-browser.enable = true;

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
      "text/plain" = ["nvim.desktop"];
      "text/markdown" = ["nvim.desktop"];
      "text/html" = ["nvim.desktop"];
      "application/json" = ["nvim.desktop"];
      "text/csv" = ["csvlens.desktop"];
      "text/comma-separated-values" = ["csvlens.desktop"];
      "application/vnd.oasis.opendocument.text" = ["nvim.desktop"];

      # Web browser scheme handlers
      "x-scheme-handler/http" = ["firefox.desktop"];
      "x-scheme-handler/https" = ["firefox.desktop"];
      "x-scheme-handler/about" = ["firefox.desktop"];
      "x-scheme-handler/unknown" = ["firefox.desktop"];

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

      # Video
      "video/mp4" = ["mpv.desktop"];
      "video/x-matroska" = ["mpv.desktop"];
      "video/webm" = ["mpv.desktop"];
      "video/x-msvideo" = ["mpv.desktop"];
      "video/quicktime" = ["mpv.desktop"];

      # Audio
      "audio/mpeg" = ["mpv.desktop"];
      "audio/flac" = ["mpv.desktop"];
      "audio/ogg" = ["mpv.desktop"];
      "audio/wav" = ["mpv.desktop"];
      "audio/x-wav" = ["mpv.desktop"];
      "audio/aac" = ["mpv.desktop"];

      # Code files
      "text/x-python" = ["nvim.desktop"];
      "text/x-shellscript" = ["nvim.desktop"];
      "text/x-yaml" = ["nvim.desktop"];
      "application/x-yaml" = ["nvim.desktop"];
      "text/x-toml" = ["nvim.desktop"];
      "application/toml" = ["nvim.desktop"];
      "text/javascript" = ["nvim.desktop"];
      "application/javascript" = ["nvim.desktop"];
      "application/typescript" = ["nvim.desktop"];
      "text/x-rust" = ["nvim.desktop"];
      "text/x-c" = ["nvim.desktop"];
      "text/x-c++" = ["nvim.desktop"];
      "text/x-go" = ["nvim.desktop"];
      "application/xml" = ["nvim.desktop"];
      "text/xml" = ["nvim.desktop"];

      # Archives
      "application/zip" = ["org.kde.ark.desktop"];
      "application/x-tar" = ["org.kde.ark.desktop"];
      "application/x-bzip" = ["org.kde.ark.desktop"];
      "application/x-xz" = ["org.kde.ark.desktop"];
      "application/gzip" = ["org.kde.ark.desktop"];
      "application/x-7z-compressed" = ["org.kde.ark.desktop"];
      "application/x-compressed-tar" = ["org.kde.ark.desktop"];

      # Other
      "application/epub+zip" = ["org.pwmt.zathura-pdf-mupdf.desktop"];
      "application/x-bittorrent" = ["org.qbittorrent.qBittorrent.desktop"];
      "inode/directory" = ["kitty-open.desktop"];
    };
    associations = {
      added = {
        "text/plain" = ["nvim.desktop"];
        "text/markdown" = ["nvim.desktop"];
        "text/json" = ["nvim.desktop"];
        "application/json" = ["nvim.desktop"];
        "text/csv" = ["csvlens.desktop"];
        "text/comma-separated-values" = ["csvlens.desktop"];
        "application/vnd.oasis.opendocument.text" = ["nvim.desktop"];

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

        "video/mp4" = ["mpv.desktop"];
        "video/x-matroska" = ["mpv.desktop"];
        "video/webm" = ["mpv.desktop"];
        "video/x-msvideo" = ["mpv.desktop"];
        "video/quicktime" = ["mpv.desktop"];

        "audio/mpeg" = ["mpv.desktop"];
        "audio/flac" = ["mpv.desktop"];
        "audio/ogg" = ["mpv.desktop"];
        "audio/wav" = ["mpv.desktop"];
        "audio/x-wav" = ["mpv.desktop"];
        "audio/aac" = ["mpv.desktop"];

        "text/x-python" = ["nvim.desktop"];
        "text/x-shellscript" = ["nvim.desktop"];
        "text/x-yaml" = ["nvim.desktop"];
        "application/x-yaml" = ["nvim.desktop"];
        "text/x-toml" = ["nvim.desktop"];
        "application/toml" = ["nvim.desktop"];
        "text/javascript" = ["nvim.desktop"];
        "application/javascript" = ["nvim.desktop"];
        "application/typescript" = ["nvim.desktop"];
        "text/x-rust" = ["nvim.desktop"];
        "text/x-c" = ["nvim.desktop"];
        "text/x-c++" = ["nvim.desktop"];
        "text/x-go" = ["nvim.desktop"];
        "application/xml" = ["nvim.desktop"];
        "text/xml" = ["nvim.desktop"];

        "application/zip" = ["org.kde.ark.desktop"];
        "application/x-tar" = ["org.kde.ark.desktop"];
        "application/x-bzip" = ["org.kde.ark.desktop"];
        "application/x-xz" = ["org.kde.ark.desktop"];
        "application/gzip" = ["org.kde.ark.desktop"];
        "application/x-7z-compressed" = ["org.kde.ark.desktop"];
        "application/x-compressed-tar" = ["org.kde.ark.desktop"];

        "application/epub+zip" = ["org.pwmt.zathura-pdf-mupdf.desktop"];
        "application/x-bittorrent" = ["org.qbittorrent.qBittorrent.desktop"];
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
    audio-select
    blesh
    winetricks
    font-awesome
    abiword
    kdePackages.ark
    blueman
    brightnessctl
    cliphist
    dejavu_fonts
    dmenu-wayland
    eww
    fira-sans
    font-awesome
    foot
    mullvad-vpn
    jitsi
    gimp3
    grimblast
    pkgsStable.hyprpaper
    pkgsStable.hyprshot
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
    nwg-look
    pavucontrol
    pyprland
    qbittorrent
    roboto
    roboto-mono
    roboto-serif
    # rustdesk
    satty
    swayimg
    mqttx
    ultimate-oldschool-pc-font-pack
    (vivaldi.override {
      commandLineArgs = " --enable-features=UseOzonePlatform --ozone-platform=wayland";
    })
    font-manager
    swayosd
    telegram-desktop
    tofi
    ubuntu-sans-mono
    way-displays
    pkgsStable.waybar
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
    wlprop
    # rustdesk
    quickshell
    wob
    # ironbar # currently returns an error releated to libedev
    distrobox
    garamond-libre
    kdePackages.qtdeclarative
    guvcview
    thunderbird
    wlprop
    wine
    pinentry-all
    librewolf
    mullvad-browser
    signal-desktop
    # open-webui
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

    ".config/quickshell" = {
      source = link "${dots}/.config/quickshell";
      recursive = true;
    };

    ".config/alacritty" = {
      source = link "${dots}/.config/alacritty";
      recursive = true;
    };

    ".config/eww" = {
      source = link "${dots}/.config/eww";
      recursive = true;
    };

    ".config/blueman" = {
      source = link "${dots}/.config/blueman";
      recursive = true;
    };

    ".config/wob" = {
      source = link "${dots}/.config/wob";
      recursive = true;
    };

    ".local/share/applications/csvlens.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=csvlens
      Comment=CSV file viewer
      Exec=kitty --hold csvlens %f
      Terminal=false
      MimeType=text/csv;text/comma-separated-values;
      Categories=Utility;Viewer;
      NoDisplay=false
    '';
  };
}
