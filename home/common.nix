{ config, pkgs, inputs, pkgsStable, ... }:
let
  homeDir = config.home.homeDirectory;
  pstore = "${homeDir}/clones/own/password-store";
in {
  home.stateVersion = "25.05";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };

  home.packages = with pkgs; [
    _1password-cli
    alejandra
    asciinema
    atuin
    bacon
    bash
    bat
    black
    blesh
    blueman
    bottom
    brightnessctl
    carapace
    cargo
    cliphist
    dejavu_fonts
    difftastic
    direnv
    eww
    eza
    eslint_d
    fastfetch
    fd
    fira-sans
    fish
    font-awesome
    foot
    fzf
    fzy
    gh
    gimp3
    git
    glow
    gnumake
    helix
    htop
    hyprpaper
    imv
    inputs.mq.packages.${pkgs.system}.mq
    jaq
    jq
    kanshi
    killall
    liberation_ttf
    mako
    mako
    neofetch
    neovide
    neovim
    nerd-fonts.blex-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.iosevka-term
    nil
    nix-search-cli
    nixfmt-classic
    nnn
    nodejs_22
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-extra
    nushell
    ollama
    onefetch
    pamixer
    pass
    pavucontrol
    pfetch
    prettierd
    pyprland
    qbittorrent
    ripgrep
    roboto
    roboto-mono
    roboto-serif
    ruby
    satty
    sendme
    hyprland-qtutils
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
    tmex
    tmux
    tofi
    tree
    typos
    typos-lsp
    ubuntu-sans-mono
    ubuntu-sans-mono
    unzip
    uv
    waybar
    wf-recorder
    wl-clipboard
    xan
    ydotool
    zoxide
    zsh
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
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config";
    ".config/foot/foot.ini".source = link "${dots}/.config/foot/foot.ini";
    ".config/tofi/config".source = link "${dots}/.config/tofi/config";
    ".config/mako/config".source = link "${dots}/.config/mako/config";
    ".config/starship.toml".source = link "${dots}/.config/starship.toml";
    ".inputrc".source = link "${dots}/.inputrc";
    ".config/direnv/direnv.toml".source =
      link "${dots}/.config/direnv/direnv.toml";

    # directories (need recursive = true)
    "scripts" = {
      source = link "${dots}/scripts";
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
