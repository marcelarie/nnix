{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  homeDir = config.home.homeDirectory;
in {
  home.packages = with pkgs; [
    # Terminal utilities
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
    
    # Development tools
    nodejs
    python3
    go
    rustc
    cargo
    
    # Text processing
    jq
    yq-go
    
    # Network tools
    openssh
    rsync
  ];

  # Import common configuration
  imports = [../../home/common.nix];

  # Android-specific configurations can be added here
  programs = {
    # Enable programs that work well on mobile
    fish.enable = true;
    starship.enable = true;
  };
}