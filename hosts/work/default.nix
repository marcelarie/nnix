{ config, pkgs, pkgsStable, ... }: {
  home.username = "mmanzanares";
  home.homeDirectory = "/home/mmanzanares";

  home.packages = with pkgs; [
    _1password-cli
    _1password-gui
    pyenv
    pnpm
    python313Packages.python-lsp-server
  ];
}
