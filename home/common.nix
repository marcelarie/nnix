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
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = ["nvim-terminal.desktop"];
      "text/markdown" = ["nvim-terminal.desktop"];
      "text/html" = ["nvim-terminal.desktop"];
      "application/json" = ["nvim-terminal.desktop"];
      "image/png" = ["swayimg.desktop" "imv.desktop"];
    };
    associations = {
      added = {
        "text/plain" = ["nvim-terminal.desktop"];
        "text/markdown" = ["nvim-terminal.desktop"];
        "text/json" = ["nvim-terminal.desktop"];
        "application/json" = ["nvim-terminal.desktop"];
        "image/png" = ["swayimg.desktop" "imv.desktop"];
      };
      removed = {
        "image/png" = ["chromium-browser.desktop"];
      };
    };
  };

  home.packages = with pkgs; [
    # inputs.mq.packages.${pkgs.system}.mq
    _1password-cli
    alejandra
    atuin
    bacon
    bash
    bash-language-server
    bat
    black
    blesh
    blueman
    bottom
    brightnessctl
    carapace
    cbfmt
    cliphist
    dejavu_fonts
    dejavu_fonts
    difftastic
    direnv
    dmenu-wayland
    dprint
    erdtree
    eslint_d
    eww
    eza
    fastfetch
    fd
    fira-sans
    fira-sans
    fish
    fixjson
    font-awesome
    foot
    fzf
    fzy
    gcc
    gh
    gimp3
    git
    glow
    gnumake
    grimblast
    helix
    htop
    hyprpaper
    hyprshot
    jaq
    java-language-server
    jdd
    jq
    kanshi
    killall
    liberation_ttf
    liberation_ttf
    mako
    mako
    marksman
    mdformat
    neofetch
    neovim
    nerd-fonts.blex-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.iosevka-term
    nil
    nil
    nix-search-cli
    nix-search-cli
    nixfmt-classic
    nixfmt-classic
    nnn
    nnn
    nodePackages_latest.vscode-json-languageserver
    nodejs_22
    nodejs_22
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-extra
    nushell
    nwg-look
    ollama
    onefetch
    pamixer
    pass
    pavucontrol
    pfetch
    poppler-utils
    prettierd
    pyprland
    qbittorrent
    qbittorrent
    rabbitmqadmin-ng
    repgrep
    ripgrep
    roboto
    roboto
    roboto-mono
    roboto-mono
    roboto-serif
    roboto-serif
    ruby
    rustdesk
    rustup
    satty
    sendme
    shfmt
    solargraph
    speedtest-cli
    speedtest-rs
    sqlite
    starship
    stylua
    sway
    swayimg
    swayosd
    sysz
    taplo
    tldr
    tldr
    tmex
    tmux
    tofi
    tree
    typos
    typos-lsp
    ubuntu-sans-mono
    ubuntu-sans-mono
    ubuntu-sans-mono
    ubuntu-sans-mono
    unzip
    uv
    way-displays
    waybar
    wf-recorder
    wl-clipboard
    wlr-layout-ui
    wofi-emoji
    xan
    ydotool
    zathura
    zoxide
    zsh
    keyd
    telegram
  ];

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
    nvim = "${clonesOwn}/nvim";
    notes = "${clonesOwn}/notes";
  in {
    # plain files
    ".vimrc".source = link "${dots}/.vimrc";
    ".gitconfig".source = link "${dots}/.gitconfig";
    ".gitignore".source = link "${dots}/.gitignore";
    ".bashrc".source = link "${dots}/.bashrc";
    ".bash_aliases".source = link "${dots}/.bash_aliases";

    # single files
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
    ".config/starship.toml".source = link "${dots}/.config/starship.toml";
    ".config/shellcheckrc".source = link "${dots}/.config/shellcheckrc";
    ".cargo/env".source = link "${dots}/.cargo/env";
    ".cargo/env.fish".source = link "${dots}/.cargo/env.fish";
    ".cargo/env.nu".source = link "${dots}/.cargo/env.nu";
    ".inputrc".source = link "${dots}/.inputrc";
    ".config/direnv/direnv.toml".source =
      link "${dots}/.config/direnv/direnv.toml";

    # directories (need recursive = true)
    "scripts" = {
      source = link "${dots}/scripts";
      recursive = true;
    };

    ".config/erdtree" = {
      source = link "${dots}/.config/erdtree";
      recursive = true;
    };

    ".password-store" = {
      source = link "${pstore}/";
      recursive = true;
    };

    ".config/fish" = {
      source = link "${dots}/.config/fish";
      recursive = true;
    };

    ".config/nushell" = {
      source = link "${dots}/.config/nushell";
      recursive = true;
    };

    ".config/waybar" = {
      source = link "${dots}/.config/waybar";
      recursive = true;
    };

    ".config/tmux" = {
      source = link "${dots}/.config/tmux";
      recursive = true;
    };
    ".config/cbfmt" = {
      source = link "${dots}/.config/cbfmt";
      recursive = true;
    };
    ".config/eww" = {
      source = link "${dots}/.config/eww";
      recursive = true;
    };
    ".config/nvim" = {
      source = link nvim;
      recursive = true;
    };
    "notes" = {
      source = link notes;
      recursive = true;
    };
  };
}
