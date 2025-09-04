{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  homeDir = "/home/marcel";
in {
  home.username = "marcel";
  home.homeDirectory = homeDir;
  imports = [
    ../../home/terminal.nix
    ../../home/gui.nix
  ];

  home.packages = with pkgs; [
    hyprlock
    hyprland-qtutils
    stremio
    zeroad
    telegram-desktop
    ungoogled-chromium
    firefox
    imv
  ];

  programs.mpv = {
    enable = true;
    scripts = [pkgs.mpvScripts.mpris];
  };

  # PipeWire configuration for Bluetooth audio stability
  xdg.configFile."pipewire/pipewire.conf.d/99-bluetooth-latency.conf".text = ''
    # PipeWire configuration for better Bluetooth audio stability
    context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 1024
        default.clock.min-quantum = 32
        default.clock.max-quantum = 2048
    }

    context.modules = [
        { name = libpipewire-module-rt
          args = {
              nice.level = -11
              rt.prio = 88
              rt.time.soft = 200000
              rt.time.hard = 200000
          }
          flags = [ ifexists nofail ]
        }
    ]
  '';

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
  in {
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config";
  };
}
