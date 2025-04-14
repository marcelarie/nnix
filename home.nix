{ config, pkgs, ... }:

{
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
  ];

  programs.bash.enable = true;

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # home.file.".vimrc".source = ./dotfiles/vimrc;
  # home.file.".gitconfig".source = ./dotfiles/gitconfig;
}

