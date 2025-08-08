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

  home.packages = with pkgs; [
    # Core CLI tools
    _1password-cli
    alejandra
    asciinema
    atuin
    bacon
    bash
    bash-language-server
    bat
    black
    bottom
    carapace
    cbfmt
    claude-code
    difftastic
    direnv
    dprint
    erdtree
    eslint_d
    eza
    fastfetch
    fd
    fish
    fixjson
    fzf
    fzy
    gcc
    gh
    git-cliff
    gitFull
    glow
    gnumake
    gping
    helix
    htop
    jaq
    java-language-server
    jdd
    jq
    just
    killall
    libwebp
    lsr
    markdown-oxide
    marksman
    mdformat
    moar
    neofetch
    neovim
    nil
    nix-diff
    nix-search-cli
    nixfmt-classic
    nnn
    nodePackages_latest.vscode-json-languageserver
    nodejs_22
    nushell
    nvim-nightly
    ollama
    onefetch
    openssl
    optipng
    pass
    patchutils
    pfetch
    poppler-utils
    prefetch-npm-deps
    prettierd
    rabbitmqadmin-ng
    repgrep
    ripgrep
    ruby
    rustup
    sendme
    shfmt
    solargraph
    speedtest-cli
    speedtest-rs
    sqlite
    starship
    stylua
    sysz
    taplo
    taskwarrior-tui
    taskwarrior3
    tldr
    tmex
    tmux
    traceroute
    tree
    trippy
    typos
    typos-lsp
    unzip
    uv
    vtsls
    w3m
    xan
    zbar
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
    ".config/starship.toml".source = link "${dots}/.config/starship.toml";
    ".config/shellcheckrc".source = link "${dots}/.config/shellcheckrc";
    ".cargo/env".source = link "${dots}/.cargo/env";
    ".cargo/env.fish".source = link "${dots}/.cargo/env.fish";
    ".cargo/env.nu".source = link "${dots}/.cargo/env.nu";
    ".inputrc".source = link "${dots}/.inputrc";
    ".taskrc".source = link "${dots}/.taskrc";
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

    ".task" = {
      source = link "${dots}/.tasks";
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

    ".config/tmux" = {
      source = link "${dots}/.config/tmux";
      recursive = true;
    };

    ".config/cbfmt" = {
      source = link "${dots}/.config/cbfmt";
      recursive = true;
    };

    ".config/nvim" = {
      source = link nvim;
      recursive = true;
    };

    ".config/tombi" = {
      source = link "${dots}/.config/tombi";
      recursive = true;
    };

    "notes" = {
      source = link notes;
      recursive = true;
    };
  };
}
