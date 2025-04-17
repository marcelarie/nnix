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
    git
    neovim
    zsh
    fish
    gh
    tmux
    htop
    wl-clipboard
    nodejs_22
    pnpm
    pass
    carapace
    atuin
    zoxide
    eza
    alejandra
    nil
    kanshi
    waybar
    ydotool
    hyprpaper
    mako
    foot
    nerd-fonts.blex-mono
    font-awesome
    swayosd
    tofi
    bash
    fzy
    nnn
    unzip
    nix-search-cli
    ruby
    solargraph
    nil
    fd
    ripgrep
    python313Packages.python-lsp-server
    starship
    direnv
    # fnm # Nix does not need version managers
    blueman
    jq
    jaq
    sqlite
    pyenv
    _1password-cli
    _1password-gui
    sendme
    cliphist
    zeroad
    home-manager
    difftastic
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

    ".config/nvim" = {
      source = link nvim;
      recursive = true;
    };
  };
}
