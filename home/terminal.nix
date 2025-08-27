{
  config,
  pkgs,
  inputs ? null,
  pkgsStable ? null,
  ...
}: let
  homeDir = config.home.homeDirectory;
  pstore = "${homeDir}/clones/own/password-store";
  terminalPackages = import ./terminal-packages.nix {inherit pkgs;};
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

  home.packages =
    terminalPackages
    ++ (with pkgs; [
      tmex
      _1password-cli
      alejandra
      asciinema
      nvim-nightly
      jdd
    ]);

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
    nvim = "${clonesOwn}/nvim";
    notes = "${clonesOwn}/notes";
  in {
    ".vimrc".source = link "${dots}/.vimrc";
    ".gitconfig".source = link "${dots}/.gitconfig";
    ".gitignore".source = link "${dots}/.gitignore";
    ".bashrc".source = link "${dots}/.bashrc";
    ".bash_aliases".source = link "${dots}/.bash_aliases";
    ".config/starship.toml".source = link "${dots}/.config/starship.toml";
    ".config/shellcheckrc".source = link "${dots}/.config/shellcheckrc";
    # ".cargo/env".source = link "${dots}/.cargo/env";
    ".cargo/env.fish".source = link "${dots}/.cargo/env.fish";
    ".cargo/env.nu".source = link "${dots}/.cargo/env.nu";
    ".inputrc".source = link "${dots}/.inputrc";
    ".taskrc".source = link "${dots}/.taskrc";
    ".config/direnv/direnv.toml".source = link "${dots}/.config/direnv/direnv.toml";
    ".claude/CLAUDE.md".source = link "${dots}/.claude/CLAUDE.md";

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
