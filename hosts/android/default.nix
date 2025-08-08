{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  terminalPackages = import ../../home/terminal-packages.nix {inherit pkgs;};
in {
  system.stateVersion = "24.05";
  
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

  user.shell = "${pkgs.fish}/bin/fish";
}
