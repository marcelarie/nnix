{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  pstore = "/home/marcel/clones/own/password-store";
in {
  imports = [../../home/common.nix];
  home.username = "marcel";
  home.homeDirectory = "/home/marcel";

  home.packages = with pkgs; [
    stremio
    zeroad
    telegram-desktop
  ];

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    dots = "/home/marcel/clones/own/dots";
    nvim = "/home/marcel/clones/own/nvim";
  in {
    # plain files
    ".vimrc".source = link "${dots}/.vimrc";
    ".gitconfig".source = link "${dots}/.gitconfig";
    ".gitignore".source = link "${dots}/.gitignore";
    ".bashrc".source = link "${dots}/.bashrc";
    ".bash_aliases".source = link "${dots}/.bash_aliases";

    # single files
    ".config/hypr/hyprland.conf".source = link "${dots}/.config/hypr/hyprland.conf";
    ".config/hypr/hypridle.conf".source = link "${dots}/.config/hypr/hypridle.conf";
    ".config/hypr/hyprlock.conf".source = link "${dots}/.config/hypr/hyprlock.conf";
    ".config/hypr/hyprpaper.conf".source = link "${dots}/.config/hypr/hyprpaper.conf";
    ".config/hypr/keybinds.conf".source = link "${dots}/.config/hypr/keybinds.conf";
    ".config/hypr/monitors.conf".source = link "${dots}/.config/hypr/monitors.conf";
    ".config/hypr/pyprland.toml".source = link "${dots}/.config/hypr/pyprland.toml";
    ".config/hypr/workspaces.conf".source = link "${dots}/.config/hypr/workspaces.conf";
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config";
    ".config/foot/foot.ini".source = link "${dots}/.config/foot/foot.ini";
    ".config/tofi/config".source = link "${dots}/.config/tofi/config";
    ".config/mako/config".source = link "${dots}/.config/mako/config";
    ".config/starship.toml".source = link "${dots}/.config/starship.toml";
    ".config/direnv/direnv.toml".source = link "${dots}/.config/direnv/direnv.toml";

    # directories (need recursive = true)
    "scripts" = {
      source = link "${dots}/scripts";
      recursive = true;
    };

    ".password-store" = {
      source = link "${pstore}/";
      recursive = true;
    };

    ".config/fish" = {
      source = link "${dots}/.config/fish";
      recursive = true;
    };

    ".config/nushell" = {
      source = link "${dots}/.config/nushell";
      recursive = true;
    };

    ".config/waybar" = {
      source = link "${dots}/.config/waybar";
      recursive = true;
    };

    ".config/tmux" = {
      source = link "${dots}/.config/tmux";
      recursive = true;
    };

    ".config/eww" = {
      source = link "${dots}/.config/eww";
      recursive = true;
    };
    ".config/nvim" = {
      source = link nvim;
      recursive = true;
    };
  };
}
