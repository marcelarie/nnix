{ config, pkgs, pkgsStable, ... }:
let homeDir = config.home.homeDirectory;
in {
  programs.firefox = {
    package = config.lib.nixGL.wrap pkgs.firefox;
  };

  home.packages = with pkgs; [
    _1password-cli
    pnpm
    # sway # for now we will install it via apt
    # python313Packages.python-lsp-server
    (config.lib.nixGL.wrap _1password-gui)
    (config.lib.nixGL.wrap _1password-gui)
    (config.lib.nixGL.wrap alacritty)
    (config.lib.nixGL.wrap neovide)
    (config.lib.nixGL.wrap imv)
    (config.lib.nixGL.wrap niri)
    (config.lib.nixGL.wrap freetube)
    (config.lib.nixGL.wrap nautilus)
    (config.lib.nixGL.wrap librewolf)
  ];

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
  in {
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config-work";
    ".cargo/env".source = link "${dots}/.cargo/env";
    ".cargo/env.fish".source = link "${dots}/.cargo/env.fish";
    ".cargo/env.nu".source = link "${dots}/.cargo/env.nu";
    ".config/hypr/devices/WS0277.conf".source =
      link "${dots}/.config/hypr/devices/WS0277.conf";
    ".mozilla/native-messaging-hosts/passff.json".source =
      "${pkgs.passff-host}/lib/mozilla/native-messaging-hosts/passff.json";
  };
}
