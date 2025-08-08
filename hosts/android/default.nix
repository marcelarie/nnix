{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  homeDir = config.home.homeDirectory;
in {
  environment.packages = with pkgs; [
    tmux
    neovim
    git
    curl
    wget
    htop
    tree
    fd
    ripgrep
    bat
    fzf

    nodejs
    python3
    go
    rustc
    cargo

    jq
    yq-go

    openssh
    rsync
  ];

  imports = [../../home/terminal.nix];

  programs = {
    fish.enable = true;
    starship.enable = true;
  };
}

