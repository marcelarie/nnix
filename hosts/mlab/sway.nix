{
  _config,
  pkgs,
  _lib,
  ...
}: {
  fonts.packages = [pkgs.myna-font];
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Experimental = true;
  };

  programs.sway = {
    # it will not run on boot
    enable = true;
    extraPackages = with pkgs; [
      foot
      tofi
      wl-clipboard
      grim
      slurp
      swappy
      libnotify
      bluetuith # bluetooth tui
    ];
  };
  security.polkit.enable = true;
}
