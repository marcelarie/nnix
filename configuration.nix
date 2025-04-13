{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # System settings
  system.stateVersion = "24.11"; 
  networking.hostName = "nixos";

  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  time.timeZone = "Europe/Madrid";
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.marcel = {
    isNormalUser = true;
    description = "Marcel";
    extraGroups = [ "wheel" "networkmanager" ];
    packages = with pkgs; [ firefox ];
  };

  # Enable services
  services.openssh.enable = true;
  services.networking.networkmanager.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}

