{ config, pkgs, pkgsStable, ... }:

{
  imports = [
    ./home/common.nix
    ./hosts/home/default.nix
  ];

  home.username = "marcel";
  home.homeDirectory = "/home/marcel";
}

