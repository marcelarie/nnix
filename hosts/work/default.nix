{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  homeDir = config.home.homeDirectory;
in {
  home.packages = with pkgs; [
    _1password-cli
    _1password-gui
    pnpm
    # sway # for now we will install it via apt
    # python313Packages.python-lsp-server
    (config.lib.nixGL.wrap alacritty)
    (config.lib.nixGL.wrap neovide)
    (config.lib.nixGL.wrap imv)
    (config.lib.nixGL.wrap niri)
    (config.lib.nixGL.wrap firefox)
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
  };
}
