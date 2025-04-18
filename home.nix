{
  config,
  pkgs,
  ...
}: let
  link = config.lib.file.mkOutOfStoreSymlink;
  pstore = "/home/marcel/clones/own/password-store";
  dots = "/home/marcel/clones/own/dots";
  nvim = "/home/marcel/clones/own/nvim";
in {
  home.username = "marcel";
  home.homeDirectory = "/home/marcel";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # fnm # Nix does not need version managers
    _1password-cli
    _1password-gui
    alejandra
    asciinema
    atuin
    auto-cpufreq
    bacon
    bash
    bat
    blueman
    bottom
    brightnessctl
    carapace
    cliphist
    difftastic
    direnv
    eww
    eza
    fastfetch
    fd
    fish
    font-awesome
    foot
    fzf
    fzy
    gh
    gimp
    git
    glow
    helix
    home-manager
    htop
    htop
    hyprpaper
    jaq
    jq
    kanshi
    killall
    mako
    mako
    neofetch
    neovide
    neovim
    nerd-fonts.blex-mono
    nerd-fonts.droid-sans-mono
    nerd-fonts.iosevka-term
    nil
    nil
    nix-search-cli
    nnn
    nodejs_22
    nushell
    ollama
    onefetch
    pamixer
    pass
    pavucontrol
    pfetch
    pnpm
    pyenv
    python313Packages.python-lsp-server
    ripgrep
    ruby
    sendme
    solargraph
    speedtest-cli
    speedtest-rs
    sqlite
    starship
    swayosd
    tmex
    tmux
    tofi
    tree
    typos
    typos-lsp
    ungoogled-chromium
    unzip
    uv
    waybar
    wl-clipboard
    xan
    ydotool
    zeroad
    zoxide
    zsh
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  home.file = {
    # plain files
    ".vimrc".source = link "${dots}/.vimrc";
    ".gitconfig".source = link "${dots}/.gitconfig";
    ".gitignore".source = link "${dots}/.gitignore";
    ".bashrc".source = link "${dots}/.bashrc";
    ".bash_aliases".source = link "${dots}/.bash_aliases";

    # single files
    ".config/hypr/hyprland.conf".source = link "${dots}/.config/hypr/hyprland.conf";
    ".config/hypr/hypridle.conf".source = link "${dots}/.config/hypr/hypridle.conf";
    ".config/hypr/hyprlock.conf".source = link "${dots}/.config/hypr/hyprlock.conf";
    ".config/hypr/hyprpaper.conf".source = link "${dots}/.config/hypr/hyprpaper.conf";
    ".config/hypr/keybinds.conf".source = link "${dots}/.config/hypr/keybinds.conf";
    ".config/hypr/monitors.conf".source = link "${dots}/.config/hypr/monitors.conf";
    ".config/hypr/pyprland.toml".source = link "${dots}/.config/hypr/pyprland.toml";
    ".config/hypr/workspaces.conf".source = link "${dots}/.config/hypr/workspaces.conf";
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config";
    ".config/foot/foot.ini".source = link "${dots}/.config/foot/foot.ini";
    ".config/tofi/config".source = link "${dots}/.config/tofi/config";
    ".config/mako/config".source = link "${dots}/.config/mako/config";
    ".config/starship.toml".source = link "${dots}/.config/starship.toml";

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

    ".config/waybar" = {
      source = link "${dots}/.config/waybar";
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
  };
}
