{
  config,
  pkgs,
  ...
}: let
  terminalPackages = import ../../home/terminal-packages.nix {inherit pkgs;};
  stateVersion = "24.05";
in {
  system.stateVersion = stateVersion;

  environment.packages =
    terminalPackages
    ++ (with pkgs; [
      # Add any Android-specific tools here
    ]);

  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    OPENSSL_DIR = "${pkgs.openssl.out}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
  };

  home-manager = {
    backupFileExtension = "hm-bak";
    useGlobalPkgs = true;

    config = {
      config,
      lib,
      pkgs,
      ...
    }: {
      home.stateVersion = stateVersion;

      home.packages = with pkgs; [
        blesh
      ];
    };
  };

  user.shell = "${pkgs.fish}/bin/fish";
}
