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
    pyenv
    pnpm
    python313Packages.python-lsp-server
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
