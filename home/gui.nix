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

  programs.firefox = {
    enable = true;

    profiles.default = {
      path = "default";
      isDefault = true;

      extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
        ublock-origin
        reddit-enhancement-suite
      ];

      # Extensions not available in NUR (install manually):
      # - Vimmatic
      # - Greasemonkey
      # - Redirector
      # - LanguageTool
      # - PassFF
      # - 1Password
      # - TWP - Translate Web Pages
      # - Keep pinned tabs alive
      # - Song id
      # - UnDistracted - Hide Facebook, YouTube Feeds
      # - UltimaDark (theme)
      # - RYS — Remove YouTube Suggestions

      bookmarks = {
        force = true;
        settings = [
        {
          name = "Bookmarks Toolbar";
          toolbar = true;
          bookmarks = [
            { name = "marcelarie - Dashboard - Codeberg.org"; url = "https://codeberg.org/"; }
            { name = "The Rustonomicon"; url = "https://doc.rust-lang.org/nomicon/index.html"; }
            { name = "Shared-State Concurrency - The Rust Programming Language"; url = "https://doc.rust-lang.org/book/ch16-03-shared-state.html"; }
            { name = "Better HN"; url = "https://bhn.vercel.app/top"; }
            { name = "Magnet search"; url = "https://btdig.com/"; }
            { name = "Sci-Hub: knowledge belongs to all mankind"; url = "https://sci-hub.st/"; }
            { name = "Opensauced"; url = "https://app.opensauced.pizza/workspaces/3164341c-c16e-47d9-8cf9-b74220432337"; }
            { name = "Anna's Archive"; url = "https://annas-archive.org/"; }
            { name = "Bitbucket Issues dashboard"; url = "https://jira.atlassian.com/projects/BSERV/issues/BSERV-19819?filter=allissues"; }
            { name = "News Minimalist"; url = "https://www.newsminimalist.com/?sort=significance"; }
            { name = "Browse Standard Ebooks - Standard Ebooks: Free and liberated ebooks, carefully produced for the true book lover"; url = "https://standardebooks.org/ebooks"; }
            { name = "cmt dev"; url = "https://cmt-dev.wocs3.com/"; }
            { name = "cmt stg"; url = "https://cmt-stg.wocs3.com/"; }
            { name = "Marcel Manzanares - Personal"; url = "https://worldsensing.bamboohr.com/employees/employee.php?id=349&page=2092"; }
            { name = "CMT - 006_ENG/Internal - Google Drive"; url = "https://drive.google.com/drive/u/1/folders/1aTJz4Omb0QXNUo1WeLrKFR_bMMRUf2q0"; }
            { name = "006_ENG/External - Google Drive"; url = "https://drive.google.com/drive/u/1/folders/0AOJLFb2bKvUfUk9PVA"; }
            { name = "Desk Booking Tool - Google Sheets"; url = "https://docs.google.com/spreadsheets/d/1YSfm1OqV_Kel-WQtCuzdLkEne_uThY6rW1CeVEWyLug/edit?gid=808998914#gid=808998914"; }
            { name = "VPN Installation | Guides"; url = "https://guide.int.worldsensing.com/books/manuals/page/vpn-installation-and-configuration"; }
            { name = "1Password"; url = "https://worldsensing.1password.eu/signin"; }
            { name = "OpenSearch Dashboards"; url = "https://opensearch.wocs3.com/app/login?nextUrl=%2Fapp%2Fdiscover#/?_g=%28filters:!%28%29,refreshInterval:%28pause:!t,value:0%29,time:%28from:now-15m,to:now%29%29&_a=%28columns:!%28_source%29,filters:!%28%29,index:dc9292e0-bc12-11ed-a5f8-df7a538a5c2e,interval:auto,query:%28language:kuery,query:%27%27%29,sort:!%28%29%29"; }
            { name = "Worldsensing | Connectivity Management Tool"; url = "https://cmt-dev.wocs3.com/login"; }
            { name = "Alan Turing - 006_ENG/Internal - Google Drive"; url = "https://drive.google.com/drive/u/1/folders/1nBsm096yv2hcJdV3NoJYj_-WStxW-KWA"; }
            { name = "Argo CD"; url = "https://argocd-dev.wocs3.com/login?return_url=https%3A%2F%2Fargocd-dev.wocs3.com%2Fapplications"; }
            { name = "Google Chat"; url = "https://mail.google.com/chat/u/1/#chat/home"; }
            { name = "Tech Debt Requests"; url = "https://ws.tpondemand.com/restui/board.aspx?#page=board/4667432318295481078&appConfig=eyJhY2lkIjoiIn0="; }
            { name = "Work Calendar"; url = "https://calendar.google.com/calendar/u/1/r/week"; }
            { name = "Component library [CMT Cloud] – Figma"; url = "https://www.figma.com/design/chpKXzkgKmQCQINNRtohvm/Component-library-%5BCMT-Cloud%5D?node-id=1773-224&t=ynpt3CRPABgMZQSh-0"; }
            { name = "Alan Turing - Team Inventory - Google Sheets"; url = "https://docs.google.com/spreadsheets/d/14W-ffaFCLPsL1KZYb2OaC4SJSKnmvOtEK_SsMsNfmzg/edit?gid=0#gid=0"; }
            { name = "Postman WS Workspace"; url = "https://web.postman.co/workspace/5c7a1002-0b1c-43fe-82fd-5fc18ed1ef63/request/41010325-5fc76bb5-24f8-4704-9522-fdc66e0cb6ac"; }
            { name = "CMT.drawio - draw.io"; url = "https://app.diagrams.net/#G1krBRlaHvGF7gaEQ8ShMSpJeB2YpB_gIg#%7B%22pageId%22%3A%22Njqf2apxFuwAC4SVHstD%22%7D"; }
            { name = "Keycloak Administration Console"; url = "https://keycloak-dev.wocs3.com/admin/master/console/"; }
            { name = "92760 Hide/DIsable Integration Creation and Visibility for Account Admins - Google Docs"; url = "https://docs.google.com/document/d/1s4vl_41iCarTXBRgcW2jezwjcMgyjycgQvPE4v9zONw/edit?tab=t.0"; }
            { name = "CMT Cloud How-To / Support - Google Docs"; url = "https://docs.google.com/document/d/1m18P6bPIX9aiusiom-J-GDEiqOuzPQANb6IYCDHh1lo/edit?tab=t.0"; }
            { name = "ThingsBoard | Home"; url = "https://thingsboard-dev.wocs3.com/home"; }
            { name = "WS Snippets — Bitbucket"; url = "https://bitbucket.org/worldsensing_traffic/workspace/snippets/"; }
            { name = "Goku M3 - Web - Front end"; url = "https://ws.tpondemand.com/restui/board.aspx?#page=feature/99189"; }
            { name = "ThreadX4 internal API - Google Docs"; url = "https://docs.google.com/document/d/1DtttiaXcZogKqotNqtJAKeR2cOuzK9ERwDy2QM3WdyU/edit?tab=t.efmodvkivcyt"; }
          ];
        }
      ];
      };

      search = {
        default = "Kagi";
        force = true;
        engines = {
          "Kagi" = {
            urls = [{
              template = "https://kagi.com/search";
              params = [
                { name = "q"; value = "{searchTerms}"; }
              ];
            }];
            definedAliases = [ "@k" ];
          };
        };
      };

      settings = {
        "ui.key.menuAccessKeyFocuses" = false;
        "browser.aboutConfig.showWarning" = false;
        "browser.bookmarks.showMobileBookmarks" = true;
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSearch" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.safebrowsing.downloads.remote.block_potentially_unwanted" = false;
        "browser.startup.homepage" = "https://kagi.com";
        "browser.startup.page" = 3;
        "browser.theme.toolbar-theme" = 0;
        "browser.urlbar.showSearchSuggestionsFirst" = false;
        "browser.urlbar.suggest.engines" = false;
        "extensions.activeThemeID" = "{f2b832a9-f0f5-4532-934c-74b25eb23fb9}";
        "general.autoScroll" = true;
        "intl.accept_languages" = "en-us,en,es-es";
        "media.eme.enabled" = true;
        "media.videocontrols.picture-in-picture.video-toggle.enabled" = false;
        "network.dns.disablePrefetch" = true;
        "network.http.speculative-parallel-limit" = 0;
        "network.prefetch-next" = false;
        "privacy.clearOnShutdown_v2.formdata" = true;
        "privacy.userContext.enabled" = true;
        "privacy.userContext.ui.enabled" = true;
        "signon.rememberSignons" = false;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
      };

#       userChrome = ''
# #TabsToolbar,
# #toolbar-menubar,
# #PersonalToolbar,
# #titlebar {
#   visibility: collapse !important;
# }
#
# #navigator-toolbox {
#   position: relative;
# }
#
# #nav-bar {
#   margin-top: -40px !important;
#   opacity: 0;
#   z-index: 1;
#   transition:
#     margin-top 0.2s ease,
#     opacity 0.2s ease !important;
# }
#
# #navigator-toolbox:focus-within #nav-bar {
#   margin-top: 0 !important;
#   opacity: 1 !important;
# }
#       '';
    };
  };

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
    vvvvvv
    pinentry-all
    mullvad-browser
    signal-desktop
    # open-webui
    socat
    jq
    llama-cpp
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
